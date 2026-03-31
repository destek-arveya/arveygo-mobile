package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeFormatter

// ═══════════════════════════════════════════════════════════════
// REPORTS SCREEN — Catalog + Detail with Charts
// ═══════════════════════════════════════════════════════════════

@Composable
fun ReportsScreen() {
    var selectedReportType by remember { mutableStateOf<String?>(null) }

    AnimatedContent(
        targetState = selectedReportType,
        transitionSpec = {
            if (targetState != null) {
                slideInHorizontally { it } + fadeIn() togetherWith slideOutHorizontally { -it } + fadeOut()
            } else {
                slideInHorizontally { -it } + fadeIn() togetherWith slideOutHorizontally { it } + fadeOut()
            }
        },
        label = "reports_nav"
    ) { reportType ->
        if (reportType == null) {
            ReportsCatalogPage(onSelectReport = { selectedReportType = it })
        } else {
            ReportDetailPage(reportType = reportType, onBack = { selectedReportType = null })
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 1) CATALOG PAGE — Grid of report types
// ═══════════════════════════════════════════════════════════════

@Composable
private fun ReportsCatalogPage(onSelectReport: (String) -> Unit) {
    val scope = rememberCoroutineScope()
    var catalogItems by remember { mutableStateOf<List<ReportCatalogItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        try {
            val json = APIService.get("/api/mobile/reports/catalog")
            val arr = json.optJSONArray("data") ?: JSONArray()
            catalogItems = (0 until arr.length()).map { i ->
                val obj = arr.getJSONObject(i)
                ReportCatalogItem(
                    type = obj.optString("type"),
                    label = obj.optString("label"),
                    description = obj.optString("description"),
                    accent = obj.optString("accent", "#6366F1")
                )
            }
        } catch (e: Exception) {
            error = e.message
        }
        isLoading = false
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        // ── Top Bar ──
        ReportsTopBar(title = "Raporlar")

        if (isLoading) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 3.dp)
            }
        } else if (error != null) {
            ErrorCard(error!!) { scope.launch { isLoading = true; error = null } }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(2),
                contentPadding = PaddingValues(16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(catalogItems) { item ->
                    ReportCatalogCard(item = item, onClick = { onSelectReport(item.type) })
                }
            }
        }
    }
}

@Composable
private fun ReportCatalogCard(item: ReportCatalogItem, onClick: () -> Unit) {
    val accent = parseColor(item.accent)
    val icon = reportIcon(item.type)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(140.dp)
            .clip(RoundedCornerShape(16.dp))
            .clickable { onClick() },
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = AppColors.Surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Icon circle
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(accent.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = accent, modifier = Modifier.size(20.dp))
            }

            Column {
                Text(
                    item.label,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.Navy,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    item.description,
                    fontSize = 11.sp,
                    color = AppColors.TextMuted,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    lineHeight = 14.sp
                )
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 2) REPORT DETAIL PAGE
// ═══════════════════════════════════════════════════════════════

@Composable
private fun ReportDetailPage(reportType: String, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var reportData by remember { mutableStateOf<JSONObject?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var currentPage by remember { mutableIntStateOf(1) }

    // Filters
    var startDate by remember { mutableStateOf(LocalDate.now().minusDays(6)) }
    var endDate by remember { mutableStateOf(LocalDate.now()) }
    var selectedVehicles by remember { mutableStateOf<Set<String>>(emptySet()) }
    var showDatePicker by remember { mutableStateOf(false) }

    // Available filter options (filled from API response)
    var vehicleOptions by remember { mutableStateOf<List<FilterOption>>(emptyList()) }

    fun buildPath(): String {
        val dateFmt = DateTimeFormatter.ISO_LOCAL_DATE
        val base = when (reportType) {
            "fuel_prices" -> "/api/mobile/reports/fuel/prices"
            else -> "/api/mobile/reports/$reportType"
        }
        val params = mutableListOf<String>()
        if (reportType != "fuel_prices") {
            params.add("start_date=${startDate.format(dateFmt)}")
            params.add("end_date=${endDate.format(dateFmt)}")
        }
        selectedVehicles.forEach { v -> params.add("vehicles[]=$v") }
        params.add("page=$currentPage")
        params.add("per_page=25")
        return "$base?${params.joinToString("&")}"
    }

    fun load() {
        scope.launch {
            isLoading = true
            error = null
            try {
                val json = APIService.get(buildPath())
                reportData = json.optJSONObject("data") ?: json
                // Extract vehicle options from filters
                val filters = reportData?.optJSONObject("filters")
                val vOpts = filters?.optJSONArray("vehicle_options")
                if (vOpts != null) {
                    vehicleOptions = (0 until vOpts.length()).map { i ->
                        val o = vOpts.getJSONObject(i)
                        FilterOption(o.optString("value"), o.optString("label"))
                    }
                }
            } catch (e: Exception) {
                error = e.message
            }
            isLoading = false
        }
    }

    LaunchedEffect(Unit) { load() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.Bg)
    ) {
        // ── Top bar with back ──
        ReportsTopBar(
            title = reportData?.optString("title") ?: reportType.replaceFirstChar { it.uppercase() },
            showBack = true,
            onBack = onBack,
            accent = parseColor(reportData?.optString("accent") ?: "#6366F1")
        )

        if (isLoading && reportData == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 3.dp)
            }
        } else if (error != null && reportData == null) {
            ErrorCard(error!!) { load() }
        } else if (reportData != null) {
            val data = reportData!!
            val accent = parseColor(data.optString("accent", "#6366F1"))

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // ── Subtitle ──
                val subtitle = data.optString("subtitle", "")
                if (subtitle.isNotEmpty()) {
                    item {
                        Text(subtitle, fontSize = 13.sp, color = AppColors.TextMuted, lineHeight = 18.sp)
                    }
                }

                // ── Filters bar ──
                item {
                    FiltersBar(
                        reportType = reportType,
                        startDate = startDate,
                        endDate = endDate,
                        vehicleOptions = vehicleOptions,
                        selectedVehicles = selectedVehicles,
                        onDateChange = { s, e -> startDate = s; endDate = e; currentPage = 1; load() },
                        onVehiclesChange = { selectedVehicles = it; currentPage = 1; load() }
                    )
                }

                // ── Summary Cards ──
                val cards = data.optJSONArray("summary_cards")
                if (cards != null && cards.length() > 0) {
                    item { SummaryCardsRow(cards, accent) }
                }

                // ── Charts ──
                val charts = data.optJSONArray("charts")
                if (charts != null) {
                    items(charts.length()) { i ->
                        val chart = charts.getJSONObject(i)
                        ChartCard(chart, accent)
                    }
                }

                // ── Leaderboards (drivers report) ──
                val leaderboards = data.optJSONObject("leaderboards")
                if (leaderboards != null) {
                    item { LeaderboardSection(leaderboards, accent) }
                }

                // ── Selected Driver Detail (drivers report) ──
                val selectedDriver = data.optJSONObject("selected_driver")
                if (selectedDriver != null) {
                    item { DriverScoreDetailCard(selectedDriver, accent) }
                }

                // ── Data Table ──
                val table = data.optJSONObject("table")
                if (table != null) {
                    item { DataTableCard(table) }
                }

                // ── Pagination ──
                val pagination = data.optJSONObject("pagination")
                if (pagination != null && pagination.optInt("last_page", 1) > 1) {
                    item {
                        PaginationBar(
                            page = pagination.optInt("page", 1),
                            lastPage = pagination.optInt("last_page", 1),
                            total = pagination.optInt("total", 0),
                            onPageChange = { currentPage = it; load() }
                        )
                    }
                }

                // Loading overlay
                if (isLoading) {
                    item {
                        Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = accent, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                        }
                    }
                }

                item { Spacer(Modifier.height(80.dp)) }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 3) SUMMARY CARDS
// ═══════════════════════════════════════════════════════════════

@Composable
private fun SummaryCardsRow(cards: JSONArray, accent: Color) {
    val items = (0 until cards.length()).map { cards.getJSONObject(it) }

    // 2-column grid
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { card ->
                    val tone = card.optString("tone", "navy")
                    val bg = toneColor(tone).copy(alpha = 0.08f)
                    val fg = toneColor(tone)

                    Card(
                        modifier = Modifier.weight(1f),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = AppColors.Surface),
                        elevation = CardDefaults.cardElevation(1.dp)
                    ) {
                        Column(modifier = Modifier.padding(14.dp)) {
                            // Tone dot + label
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(fg)
                                )
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    card.optString("label"),
                                    fontSize = 11.sp,
                                    color = AppColors.TextMuted,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                            Spacer(Modifier.height(8.dp))
                            Text(
                                card.optString("value"),
                                fontSize = 22.sp,
                                fontWeight = FontWeight.Bold,
                                color = AppColors.Navy
                            )
                        }
                    }
                }
                // Fill remaining space if odd count
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 4) CHART COMPONENTS
// ═══════════════════════════════════════════════════════════════

@Composable
private fun ChartCard(chart: JSONObject, accent: Color) {
    val type = chart.optString("type", "bars")
    val title = chart.optString("title", "")

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = AppColors.Surface),
        elevation = CardDefaults.cardElevation(1.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (title.isNotEmpty()) {
                Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                Spacer(Modifier.height(14.dp))
            }

            when (type) {
                "bars" -> BarChart(chart, accent)
                "trend" -> TrendChart(chart, accent)
                "ranking" -> RankingList(chart, accent)
                "stacked" -> StackedBarChart(chart)
                "heatmap" -> HeatmapChart(chart, accent)
                else -> BarChart(chart, accent)
            }
        }
    }
}

// ── Bar Chart ──
@Composable
private fun BarChart(chart: JSONObject, accent: Color) {
    val bars = chart.optJSONArray("bars") ?: return
    val items = (0 until bars.length()).map { bars.getJSONObject(it) }
    if (items.isEmpty()) return

    // Find max numeric value for proportional bars
    val maxVal = items.maxOfOrNull { extractNumeric(it.optString("value", "0")) } ?: 1.0

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        items.forEach { bar ->
            val label = bar.optString("label", "")
            val valueStr = bar.optString("value", "0")
            val numVal = extractNumeric(valueStr)
            val pct = if (maxVal > 0) (numVal / maxVal).toFloat().coerceIn(0.05f, 1f) else 0.1f

            Column {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(label, fontSize = 12.sp, color = AppColors.TextSecondary, modifier = Modifier.weight(1f))
                    Text(
                        if (valueStr.contains(" ")) valueStr else "$valueStr",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.Navy
                    )
                }
                Spacer(Modifier.height(4.dp))
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(accent.copy(alpha = 0.08f))
                ) {
                    Box(
                        Modifier
                            .fillMaxWidth(pct)
                            .fillMaxHeight()
                            .clip(RoundedCornerShape(4.dp))
                            .background(
                                Brush.horizontalGradient(
                                    listOf(accent, accent.copy(alpha = 0.7f))
                                )
                            )
                    )
                }
            }
        }
    }
}

// ── Trend (Line-like) Chart ──
@Composable
private fun TrendChart(chart: JSONObject, accent: Color) {
    val points = chart.optJSONArray("points") ?: return
    val items = (0 until points.length()).map { points.getJSONObject(it) }
    if (items.isEmpty()) return

    val values = items.map { extractNumeric(it.optString("value", "0")) }
    val maxVal = values.max().coerceAtLeast(1.0)

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        // Bars as mini trend
        Row(
            modifier = Modifier.fillMaxWidth().height(100.dp),
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            items.forEachIndexed { idx, pt ->
                val v = values[idx]
                val hFraction = (v / maxVal).toFloat().coerceIn(0.02f, 1f)
                val barColor = if (pt.has("color")) parseColor(pt.optString("color")) else accent

                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Value label
                    Text(
                        pt.optString("value", ""),
                        fontSize = 8.sp,
                        color = AppColors.TextMuted,
                        textAlign = TextAlign.Center,
                        maxLines = 1
                    )
                    Spacer(Modifier.height(2.dp))
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .fillMaxHeight(hFraction)
                            .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                            .background(barColor.copy(alpha = 0.85f))
                    )
                }
            }
        }
        // Labels row
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            items.forEach { pt ->
                Text(
                    pt.optString("label", ""),
                    fontSize = 8.sp,
                    color = AppColors.TextFaint,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

// ── Ranking List ──
@Composable
private fun RankingList(chart: JSONObject, accent: Color) {
    val items = chart.optJSONArray("items") ?: return
    val list = (0 until items.length()).map { items.getJSONObject(it) }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        list.forEachIndexed { idx, item ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.Bg)
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Rank badge
                Box(
                    Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(
                            if (idx == 0) accent.copy(alpha = 0.15f)
                            else AppColors.BorderSoft.copy(alpha = 0.3f)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "${idx + 1}",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        color = if (idx == 0) accent else AppColors.TextMuted
                    )
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        item.optString("label", ""),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.Navy,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    val sub = item.optString("sub", "")
                    if (sub.isNotEmpty()) {
                        Text(sub, fontSize = 11.sp, color = AppColors.TextMuted)
                    }
                }
                Text(
                    item.optString("value", ""),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = accent
                )
            }
        }
    }
}

// ── Stacked Bar Chart ──
@Composable
private fun StackedBarChart(chart: JSONObject) {
    val rows = chart.optJSONArray("rows") ?: return
    val list = (0 until rows.length()).map { rows.getJSONObject(it) }
    val colors = listOf(Color(0xFFd97706), Color(0xFF16a34a), Color(0xFF6366F1), Color(0xFF0ea5e9))

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        list.forEach { row ->
            Column {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(
                        row.optString("label", ""),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.Navy
                    )
                    Text(
                        row.optString("total_label", ""),
                        fontSize = 12.sp,
                        color = AppColors.TextMuted
                    )
                }
                Spacer(Modifier.height(6.dp))

                // Stacked bar
                val segments = row.optJSONArray("segments")
                if (segments != null) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .height(12.dp)
                            .clip(RoundedCornerShape(6.dp))
                    ) {
                        for (j in 0 until segments.length()) {
                            val seg = segments.getJSONObject(j)
                            val pct = seg.optDouble("percent", 0.0).toFloat() / 100f
                            Box(
                                Modifier
                                    .weight(pct.coerceAtLeast(0.01f))
                                    .fillMaxHeight()
                                    .background(colors[j % colors.size].copy(alpha = 0.8f))
                            )
                        }
                    }
                    // Legend
                    Spacer(Modifier.height(4.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        for (j in 0 until segments.length()) {
                            val seg = segments.getJSONObject(j)
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(colors[j % colors.size])
                                )
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    "${seg.optString("label")} %${seg.optInt("percent")}",
                                    fontSize = 10.sp,
                                    color = AppColors.TextMuted
                                )
                            }
                        }
                    }
                }

                val meta = row.optString("meta", "")
                if (meta.isNotEmpty()) {
                    Text(meta, fontSize = 10.sp, color = AppColors.TextFaint, modifier = Modifier.padding(top = 2.dp))
                }
            }
        }
    }
}

// ── Heatmap Chart ──
@Composable
private fun HeatmapChart(chart: JSONObject, accent: Color) {
    val matrix = chart.optJSONObject("matrix") ?: return
    val cols = matrix.optJSONArray("columns") ?: return
    val rows = matrix.optJSONArray("rows") ?: return
    val colLabels = (0 until cols.length()).map { cols.getString(it) }

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        // Header
        Row(Modifier.fillMaxWidth()) {
            Spacer(Modifier.width(50.dp))
            colLabels.forEach { col ->
                Text(
                    col,
                    fontSize = 9.sp,
                    color = AppColors.TextMuted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f)
                )
            }
        }
        // Rows
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i)
            val dayLabel = row.optString("label", "")
            val vals = row.optJSONArray("values") ?: continue

            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    dayLabel,
                    fontSize = 10.sp,
                    color = AppColors.TextMuted,
                    modifier = Modifier.width(50.dp)
                )
                for (j in 0 until vals.length()) {
                    val v = vals.optInt(j, 0)
                    val intensity = (v / 10.0).toFloat().coerceIn(0f, 1f)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1.6f)
                            .padding(1.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(
                                if (v == 0) AppColors.Bg
                                else accent.copy(alpha = 0.1f + intensity * 0.7f)
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        if (v > 0) {
                            Text(
                                "$v",
                                fontSize = 9.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (intensity > 0.5f) Color.White else accent
                            )
                        }
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 5) LEADERBOARD (Driver Score Report)
// ═══════════════════════════════════════════════════════════════

@Composable
private fun LeaderboardSection(leaderboards: JSONObject, accent: Color) {
    val best = leaderboards.optJSONArray("best")
    val risk = leaderboards.optJSONArray("risk")

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = AppColors.Surface),
        elevation = CardDefaults.cardElevation(1.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Sürücü Sıralaması", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Spacer(Modifier.height(12.dp))

            if (best != null) {
                for (i in 0 until best.length()) {
                    val d = best.getJSONObject(i)
                    LeaderboardRow(
                        rank = i + 1,
                        name = d.optString("driver_name"),
                        score = d.optInt("total_score"),
                        label = d.optString("status_label"),
                        accent = accent
                    )
                    if (i < best.length() - 1) Spacer(Modifier.height(8.dp))
                }
            }
        }
    }
}

@Composable
private fun LeaderboardRow(rank: Int, name: String, score: Int, label: String, accent: Color) {
    val scoreColor = when {
        score >= 80 -> Color(0xFF16a34a)
        score >= 60 -> Color(0xFFd97706)
        else -> Color(0xFFdc2626)
    }

    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(AppColors.Bg)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Rank
        Box(
            Modifier
                .size(30.dp)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Text("#$rank", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = accent)
        }
        Spacer(Modifier.width(12.dp))

        Column(Modifier.weight(1f)) {
            Text(name, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
            Text(label, fontSize = 11.sp, color = AppColors.TextMuted)
        }

        // Score circle
        Box(
            Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(scoreColor.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Text("$score", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = scoreColor)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 6) DRIVER SCORE DETAIL CARD
// ═══════════════════════════════════════════════════════════════

@Composable
private fun DriverScoreDetailCard(driver: JSONObject, accent: Color) {
    val totalScore = driver.optInt("total_score", 0)
    val safetyScore = driver.optInt("safety_score", 0)
    val efficiencyScore = driver.optInt("efficiency_score", 0)
    val disciplineScore = driver.optInt("discipline_score", 0)
    val driverName = driver.optString("driver_name", "")

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = AppColors.Surface),
        elevation = CardDefaults.cardElevation(1.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Avatar
                Box(
                    Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(accent.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        driverName.take(1).uppercase(),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = accent
                    )
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(driverName, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                    Text(
                        "Genel Skor: $totalScore / 100",
                        fontSize = 12.sp,
                        color = AppColors.TextMuted
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            // Score bars
            ScoreBar("Güvenlik", safetyScore, Color(0xFF16a34a))
            Spacer(Modifier.height(8.dp))
            ScoreBar("Verimlilik", efficiencyScore, Color(0xFF6366F1))
            Spacer(Modifier.height(8.dp))
            ScoreBar("Disiplin", disciplineScore, Color(0xFFd97706))

            // AI Analysis
            val ai = driver.optJSONObject("ai_analysis")
            if (ai != null) {
                Spacer(Modifier.height(16.dp))
                Box(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(Color(0xFFFEF3C7))
                        .padding(12.dp)
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Default.AutoAwesome,
                                null,
                                tint = Color(0xFFd97706),
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.width(6.dp))
                            Text("AI Analiz", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFF92400e))
                        }
                        Spacer(Modifier.height(6.dp))
                        Text(
                            ai.optString("summary", ai.optString("headline", "")),
                            fontSize = 12.sp,
                            color = Color(0xFF78350f),
                            lineHeight = 16.sp
                        )
                    }
                }
            }

            // Trend chart
            val trend = driver.optJSONArray("trend_chart")
            if (trend != null && trend.length() > 0) {
                Spacer(Modifier.height(16.dp))
                Text("Günlük Skor Trendi", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                Spacer(Modifier.height(8.dp))
                TrendChart(
                    JSONObject().apply { put("points", trend) },
                    accent
                )
            }

            // Behavior counts
            val behaviors = driver.optJSONObject("behavior_counts")
            if (behaviors != null) {
                Spacer(Modifier.height(16.dp))
                Text("Davranış Detayları", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                Spacer(Modifier.height(8.dp))

                val behaviorMap = mapOf(
                    "harsh_braking_count" to "Sert Fren",
                    "harsh_cornering_count" to "Sert Direksiyon",
                    "harsh_acceleration_count" to "Sert Hızlanma",
                    "off_hours_usage_count" to "Mesai Dışı",
                    "towing_count" to "Taşıma/Çekme",
                    "speed_violation_count" to "Hız İhlali"
                )

                behaviorMap.forEach { (key, label) ->
                    val count = behaviors.optInt(key, 0)
                    if (count > 0) {
                        Row(
                            Modifier
                                .fillMaxWidth()
                                .padding(vertical = 3.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(label, fontSize = 12.sp, color = AppColors.TextSecondary)
                            Text(
                                "$count",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (count > 5) Color(0xFFdc2626) else AppColors.Navy
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ScoreBar(label: String, score: Int, color: Color) {
    Column {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(label, fontSize = 12.sp, color = AppColors.TextSecondary)
            Text("$score", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = color)
        }
        Spacer(Modifier.height(4.dp))
        Box(
            Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(color.copy(alpha = 0.1f))
        ) {
            Box(
                Modifier
                    .fillMaxWidth(score / 100f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(3.dp))
                    .background(color)
            )
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 7) DATA TABLE
// ═══════════════════════════════════════════════════════════════

@Composable
private fun DataTableCard(table: JSONObject) {
    val columns = table.optJSONArray("columns") ?: return
    val rows = table.optJSONArray("rows") ?: return
    val colList = (0 until columns.length()).map { columns.getString(it) }
    val rowList = (0 until rows.length()).map { rows.getJSONObject(it) }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = AppColors.Surface),
        elevation = CardDefaults.cardElevation(1.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.TableChart, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Detay Tablosu", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                Spacer(Modifier.weight(1f))
                Text("${rowList.size} kayıt", fontSize = 11.sp, color = AppColors.TextMuted)
            }
            Spacer(Modifier.height(12.dp))

            // Horizontal scroll table
            val scrollState = rememberScrollState()
            Column(
                modifier = Modifier.horizontalScroll(scrollState)
            ) {
                // Header row
                Row(
                    Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(AppColors.Navy.copy(alpha = 0.06f))
                        .padding(vertical = 8.dp, horizontal = 8.dp)
                ) {
                    colList.forEach { col ->
                        Text(
                            col,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = AppColors.Navy,
                            modifier = Modifier.width(100.dp),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }

                // Data rows
                rowList.forEachIndexed { idx, row ->
                    Row(
                        Modifier
                            .then(
                                if (idx % 2 == 0) Modifier.background(Color.Transparent)
                                else Modifier.background(AppColors.Bg.copy(alpha = 0.5f))
                            )
                            .padding(vertical = 8.dp, horizontal = 8.dp)
                    ) {
                        colList.forEach { col ->
                            // Try to find value by column name or index
                            val value = row.optString(col, "")
                                .ifEmpty { findValueByIndex(row, colList.indexOf(col)) }

                            Text(
                                value,
                                fontSize = 11.sp,
                                color = AppColors.TextSecondary,
                                modifier = Modifier.width(100.dp),
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 8) FILTERS BAR
// ═══════════════════════════════════════════════════════════════

@Composable
private fun FiltersBar(
    reportType: String,
    startDate: LocalDate,
    endDate: LocalDate,
    vehicleOptions: List<FilterOption>,
    selectedVehicles: Set<String>,
    onDateChange: (LocalDate, LocalDate) -> Unit,
    onVehiclesChange: (Set<String>) -> Unit
) {
    var showDateSheet by remember { mutableStateOf(false) }
    var showVehicleSheet by remember { mutableStateOf(false) }
    val dateFmt = DateTimeFormatter.ofPattern("dd MMM")

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Date range chip
        if (reportType != "fuel_prices") {
            FilterChip(
                selected = true,
                onClick = { showDateSheet = true },
                label = {
                    Text(
                        "${startDate.format(dateFmt)} – ${endDate.format(dateFmt)}",
                        fontSize = 12.sp
                    )
                },
                leadingIcon = { Icon(Icons.Default.DateRange, null, Modifier.size(16.dp)) },
                shape = RoundedCornerShape(10.dp),
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = AppColors.Indigo.copy(alpha = 0.08f),
                    selectedLabelColor = AppColors.Indigo,
                    selectedLeadingIconColor = AppColors.Indigo
                )
            )
        }

        // Vehicle chip (multi-select)
        if (vehicleOptions.isNotEmpty()) {
            val vehicleLabel = when {
                selectedVehicles.isEmpty() -> "Tüm Araçlar"
                selectedVehicles.size == 1 -> vehicleOptions.find { it.value == selectedVehicles.first() }?.label ?: "1 Araç"
                else -> "${selectedVehicles.size} Araç"
            }
            FilterChip(
                selected = selectedVehicles.isNotEmpty(),
                onClick = { showVehicleSheet = true },
                label = {
                    Text(vehicleLabel, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                },
                leadingIcon = { Icon(Icons.Default.DirectionsCar, null, Modifier.size(16.dp)) },
                shape = RoundedCornerShape(10.dp),
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = AppColors.Indigo.copy(alpha = 0.08f),
                    selectedLabelColor = AppColors.Indigo,
                    selectedLeadingIconColor = AppColors.Indigo
                )
            )
        }
    }

    // Date range bottom sheet
    if (showDateSheet) {
        DateRangeSheet(
            startDate = startDate,
            endDate = endDate,
            onConfirm = { s, e -> onDateChange(s, e); showDateSheet = false },
            onDismiss = { showDateSheet = false }
        )
    }

    // Vehicle multi-selection bottom sheet
    if (showVehicleSheet) {
        VehicleMultiSelectSheet(
            options = vehicleOptions,
            selectedVehicles = selectedVehicles,
            onConfirm = { onVehiclesChange(it); showVehicleSheet = false },
            onDismiss = { showVehicleSheet = false }
        )
    }
}

// ── Date Range Sheet (Custom Range + Presets, max 3 months) ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DateRangeSheet(
    startDate: LocalDate,
    endDate: LocalDate,
    onConfirm: (LocalDate, LocalDate) -> Unit,
    onDismiss: () -> Unit
) {
    var tempStart by remember { mutableStateOf(startDate) }
    var tempEnd by remember { mutableStateOf(endDate) }
    var pickingStart by remember { mutableStateOf(true) }
    var validationError by remember { mutableStateOf<String?>(null) }
    val today = LocalDate.now()
    val maxRangeMonths = 3L

    val presets = listOf(
        "Bugün" to (today to today),
        "Dün" to (today.minusDays(1) to today.minusDays(1)),
        "Son 7 Gün" to (today.minusDays(6) to today),
        "Son 30 Gün" to (today.minusDays(29) to today),
        "Bu Ay" to (today.withDayOfMonth(1) to today),
        "Geçen Ay" to (today.minusMonths(1).withDayOfMonth(1) to today.minusMonths(1).withDayOfMonth(today.minusMonths(1).lengthOfMonth())),
        "Son 3 Ay" to (today.minusMonths(3) to today),
    )

    fun validate(s: LocalDate, e: LocalDate): Boolean {
        if (e.isBefore(s)) {
            validationError = "Bitiş tarihi başlangıçtan önce olamaz"
            return false
        }
        if (s.plusMonths(maxRangeMonths).isBefore(e)) {
            validationError = "Maksimum 3 aylık aralık seçilebilir"
            return false
        }
        if (s.isAfter(today)) {
            validationError = "Gelecek tarih seçilemez"
            return false
        }
        validationError = null
        return true
    }

    // Run validation whenever dates change
    LaunchedEffect(tempStart, tempEnd) { validate(tempStart, tempEnd) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = AppColors.Surface,
        shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
    ) {
        Column(
            modifier = Modifier
                .padding(horizontal = 20.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState())
        ) {
            Text("Tarih Aralığı", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
            Spacer(Modifier.height(4.dp))
            Text("Maksimum 3 ay seçilebilir", fontSize = 12.sp, color = AppColors.TextMuted)
            Spacer(Modifier.height(16.dp))

            // ── Quick Presets ──
            Text("Hızlı Seçim", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextSecondary)
            Spacer(Modifier.height(8.dp))

            // Flow-like preset chips
            val rows = presets.chunked(3)
            rows.forEach { chunk ->
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(bottom = 6.dp)) {
                    chunk.forEach { (label, range) ->
                        val isActive = tempStart == range.first && tempEnd == range.second
                        Surface(
                            onClick = {
                                tempStart = range.first; tempEnd = range.second
                                if (validate(range.first, range.second)) {
                                    onConfirm(range.first, range.second)
                                }
                            },
                            shape = RoundedCornerShape(8.dp),
                            color = if (isActive) AppColors.Indigo.copy(alpha = 0.12f) else AppColors.Bg,
                            border = BorderStroke(1.dp, if (isActive) AppColors.Indigo.copy(alpha = 0.3f) else AppColors.BorderSoft)
                        ) {
                            Text(
                                label,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                                fontSize = 12.sp,
                                fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
                                color = if (isActive) AppColors.Indigo else AppColors.TextSecondary
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(16.dp))
            HorizontalDivider(color = AppColors.BorderSoft)
            Spacer(Modifier.height(16.dp))

            // ── Custom Date Pickers ──
            Text("Özel Tarih Seçimi", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextSecondary)
            Spacer(Modifier.height(12.dp))

            // Start / End toggle
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(AppColors.Bg),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                listOf(true to "Başlangıç" , false to "Bitiş").forEach { (isStart, label) ->
                    val active = pickingStart == isStart
                    val dateVal = if (isStart) tempStart else tempEnd
                    Surface(
                        onClick = { pickingStart = isStart },
                        shape = RoundedCornerShape(10.dp),
                        color = if (active) AppColors.Indigo else Color.Transparent,
                        modifier = Modifier.weight(1f).padding(4.dp)
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(vertical = 10.dp)
                        ) {
                            Text(
                                label,
                                fontSize = 11.sp,
                                color = if (active) Color.White.copy(alpha = 0.8f) else AppColors.TextMuted
                            )
                            Spacer(Modifier.height(2.dp))
                            Text(
                                dateVal.format(DateTimeFormatter.ofPattern("dd MMM yyyy")),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = if (active) Color.White else AppColors.Navy
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            // DatePicker
            val datePickerState = rememberDatePickerState(
                initialSelectedDateMillis = if (pickingStart)
                    tempStart.atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli()
                else
                    tempEnd.atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli(),
                selectableDates = object : SelectableDates {
                    override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                        val d = java.time.Instant.ofEpochMilli(utcTimeMillis).atZone(java.time.ZoneOffset.UTC).toLocalDate()
                        return !d.isAfter(today)
                    }
                }
            )

            // Sync DatePicker when tab changes
            LaunchedEffect(pickingStart) {
                val millis = if (pickingStart)
                    tempStart.atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli()
                else
                    tempEnd.atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli()
                datePickerState.selectedDateMillis = millis
            }

            // Update tempStart/tempEnd when user picks a date
            LaunchedEffect(datePickerState.selectedDateMillis) {
                datePickerState.selectedDateMillis?.let { millis ->
                    val picked = java.time.Instant.ofEpochMilli(millis).atZone(java.time.ZoneOffset.UTC).toLocalDate()
                    if (pickingStart) {
                        tempStart = picked
                        if (picked.isAfter(tempEnd)) tempEnd = picked
                    } else {
                        tempEnd = picked
                        if (picked.isBefore(tempStart)) tempStart = picked
                    }
                }
            }

            DatePicker(
                state = datePickerState,
                showModeToggle = false,
                title = null,
                headline = null,
                modifier = Modifier.fillMaxWidth(),
                colors = DatePickerDefaults.colors(
                    selectedDayContainerColor = AppColors.Indigo,
                    todayContentColor = AppColors.Indigo,
                    todayDateBorderColor = AppColors.Indigo
                )
            )

            // Validation error
            if (validationError != null) {
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.ErrorOutline, null, tint = Color(0xFFDC2626), modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(validationError!!, fontSize = 12.sp, color = Color(0xFFDC2626))
                }
            }

            Spacer(Modifier.height(16.dp))

            // Confirm button
            Button(
                onClick = { if (validate(tempStart, tempEnd)) onConfirm(tempStart, tempEnd) },
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(12.dp),
                enabled = validationError == null,
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Indigo,
                    disabledContainerColor = AppColors.Indigo.copy(alpha = 0.4f)
                )
            ) {
                Icon(Icons.Default.Check, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text("Uygula", fontWeight = FontWeight.SemiBold)
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

// ── Vehicle Multi-Select Sheet (Searchable + Checkboxes) ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VehicleMultiSelectSheet(
    options: List<FilterOption>,
    selectedVehicles: Set<String>,
    onConfirm: (Set<String>) -> Unit,
    onDismiss: () -> Unit
) {
    var tempSelected by remember { mutableStateOf(selectedVehicles) }
    var searchQuery by remember { mutableStateOf("") }

    val filtered = remember(searchQuery, options) {
        if (searchQuery.isBlank()) options
        else options.filter { it.label.contains(searchQuery, ignoreCase = true) }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = AppColors.Surface,
        shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
    ) {
        Column(modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Araç Seçin", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                Spacer(Modifier.weight(1f))
                if (tempSelected.isNotEmpty()) {
                    Surface(
                        onClick = { tempSelected = emptySet() },
                        shape = RoundedCornerShape(8.dp),
                        color = Color(0xFFDC2626).copy(alpha = 0.08f)
                    ) {
                        Text(
                            "Temizle",
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            fontSize = 12.sp,
                            color = Color(0xFFDC2626),
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
            Text(
                if (tempSelected.isEmpty()) "Tüm araçlar gösterilecek" else "${tempSelected.size} araç seçili",
                fontSize = 12.sp,
                color = AppColors.TextMuted
            )
            Spacer(Modifier.height(12.dp))

            // Search bar
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                placeholder = { Text("Araç ara…", fontSize = 14.sp) },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
                trailingIcon = {
                    if (searchQuery.isNotEmpty()) {
                        IconButton(onClick = { searchQuery = "" }) {
                            Icon(Icons.Default.Close, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AppColors.Indigo,
                    unfocusedBorderColor = AppColors.BorderSoft,
                    focusedContainerColor = AppColors.Bg,
                    unfocusedContainerColor = AppColors.Bg
                ),
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))

            // Select all / deselect all
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .clickable {
                        tempSelected = if (tempSelected.size == options.size)
                            emptySet()
                        else
                            options.map { it.value }.toSet()
                    }
                    .padding(vertical = 10.dp, horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Checkbox(
                    checked = tempSelected.size == options.size && options.isNotEmpty(),
                    onCheckedChange = {
                        tempSelected = if (it) options.map { o -> o.value }.toSet() else emptySet()
                    },
                    colors = CheckboxDefaults.colors(checkedColor = AppColors.Indigo)
                )
                Spacer(Modifier.width(8.dp))
                Text("Tümünü Seç", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
            }

            HorizontalDivider(color = AppColors.BorderSoft)

            // Vehicle list
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 300.dp)
            ) {
                items(filtered) { opt ->
                    val isChecked = tempSelected.contains(opt.value)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isChecked) AppColors.Indigo.copy(alpha = 0.06f) else Color.Transparent)
                            .clickable {
                                tempSelected = if (isChecked)
                                    tempSelected - opt.value
                                else
                                    tempSelected + opt.value
                            }
                            .padding(vertical = 10.dp, horizontal = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(
                            checked = isChecked,
                            onCheckedChange = {
                                tempSelected = if (it)
                                    tempSelected + opt.value
                                else
                                    tempSelected - opt.value
                            },
                            colors = CheckboxDefaults.colors(checkedColor = AppColors.Indigo)
                        )
                        Spacer(Modifier.width(8.dp))
                        Icon(Icons.Default.DirectionsCar, null, tint = if (isChecked) AppColors.Indigo else AppColors.TextMuted, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(
                            opt.label,
                            fontSize = 14.sp,
                            color = if (isChecked) AppColors.Navy else AppColors.TextSecondary,
                            fontWeight = if (isChecked) FontWeight.Medium else FontWeight.Normal
                        )
                    }
                }

                if (filtered.isEmpty()) {
                    item {
                        Text(
                            "Araç bulunamadı",
                            modifier = Modifier.fillMaxWidth().padding(24.dp),
                            fontSize = 14.sp,
                            color = AppColors.TextMuted,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            // Confirm button
            Button(
                onClick = { onConfirm(tempSelected) },
                modifier = Modifier.fillMaxWidth().height(48.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo)
            ) {
                Icon(Icons.Default.Check, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(
                    if (tempSelected.isEmpty()) "Tüm Araçları Göster" else "${tempSelected.size} Araç Seçildi — Uygula",
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 9) PAGINATION
// ═══════════════════════════════════════════════════════════════

@Composable
private fun PaginationBar(page: Int, lastPage: Int, total: Int, onPageChange: (Int) -> Unit) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = { if (page > 1) onPageChange(page - 1) }, enabled = page > 1) {
            Icon(Icons.Default.ChevronLeft, null, tint = if (page > 1) AppColors.Indigo else AppColors.TextFaint)
        }
        Text(
            "$page / $lastPage",
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = AppColors.Navy
        )
        Text(
            "  ($total kayıt)",
            fontSize = 11.sp,
            color = AppColors.TextMuted
        )
        IconButton(onClick = { if (page < lastPage) onPageChange(page + 1) }, enabled = page < lastPage) {
            Icon(Icons.Default.ChevronRight, null, tint = if (page < lastPage) AppColors.Indigo else AppColors.TextFaint)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// 10) COMMON UI COMPONENTS
// ═══════════════════════════════════════════════════════════════

@Composable
private fun ReportsTopBar(
    title: String,
    showBack: Boolean = false,
    onBack: (() -> Unit)? = null,
    onMenuClick: (() -> Unit)? = null,
    accent: Color = AppColors.Indigo
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF0A1158), Color(0xFF090F41))
                )
            )
            .statusBarsPadding()
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (showBack) {
                IconButton(onClick = { onBack?.invoke() }, modifier = Modifier.size(36.dp)) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White)
                }
                Spacer(Modifier.width(8.dp))
            }
            Text(
                title,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun ErrorCard(message: String, onRetry: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Card(
            modifier = Modifier.padding(32.dp),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = AppColors.Surface)
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Icon(Icons.Default.ErrorOutline, null, tint = Color(0xFFdc2626), modifier = Modifier.size(40.dp))
                Spacer(Modifier.height(12.dp))
                Text(message, fontSize = 14.sp, color = AppColors.TextSecondary, textAlign = TextAlign.Center)
                Spacer(Modifier.height(16.dp))
                Button(
                    onClick = onRetry,
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo)
                ) {
                    Text("Tekrar Dene")
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// DATA MODELS & HELPERS
// ═══════════════════════════════════════════════════════════════

private data class ReportCatalogItem(
    val type: String,
    val label: String,
    val description: String,
    val accent: String
)

private data class FilterOption(val value: String, val label: String)

private fun reportIcon(type: String): ImageVector = when (type) {
    "distance" -> Icons.Default.Route
    "speed" -> Icons.Default.Speed
    "stops" -> Icons.Default.PauseCircle
    "fuel" -> Icons.Default.LocalGasStation
    "fuel_prices" -> Icons.Default.AttachMoney
    "off_hours" -> Icons.Default.NightsStay
    "drivers" -> Icons.Default.Person
    "temperature" -> Icons.Default.Thermostat
    "alarms" -> Icons.Default.NotificationsActive
    "geofence" -> Icons.Default.Hexagon
    else -> Icons.Default.BarChart
}

private fun parseColor(hex: String): Color {
    return try {
        Color(android.graphics.Color.parseColor(hex))
    } catch (_: Exception) {
        Color(0xFF6366F1)
    }
}

private fun toneColor(tone: String): Color = when (tone) {
    "navy" -> Color(0xFF0F172A)
    "soft-blue" -> Color(0xFF3B82F6)
    "success" -> Color(0xFF16A34A)
    "warning" -> Color(0xFFD97706)
    "danger" -> Color(0xFFDC2626)
    "soft-red" -> Color(0xFFEF4444)
    else -> Color(0xFF6366F1)
}

private fun extractNumeric(s: String): Double {
    return try {
        s.replace(Regex("[^0-9.,\\-]"), "")
            .replace(",", ".")
            .replace(Regex("\\.(?=.*\\.)"), "")
            .toDoubleOrNull() ?: 0.0
    } catch (_: Exception) {
        0.0
    }
}

private fun findValueByIndex(row: JSONObject, index: Int): String {
    val keys = row.keys().asSequence().toList()
    return if (index in keys.indices) {
        row.optString(keys[index], "")
    } else ""
}
