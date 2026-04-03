package com.arveya.arveygo.ui.screens.fleet

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.arveya.arveygo.models.AlarmEvent
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.components.AlarmEventsSkeletonList
import com.arveya.arveygo.ui.components.AlarmRulesSkeletonList
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

private const val MOBILE_PRIVATE_IGNITION_ALARM_PREFIX = "__mobile_private_ign__"

// MARK: - Alarm Set Model (API: /api/mobile/alarm-sets/)
data class AlarmSet(
    val id: Int,
    val name: String,
    val description: String?,
    val alarmType: String,
    val status: String,
    val evaluationMode: String,
    val sourceMode: String,
    val cooldownSec: Int,
    val isActive: Boolean,
    val conditionSummary: String,
    val channelCodes: String,
    val targetCount: Int,
    val channelCount: Int,
    val recipientCount: Int,
    val createdAt: String
) {
    val icon: ImageVector get() = when (alarmType) {
        "speed_violation" -> Icons.Default.Speed
        "geofence_alarm" -> Icons.Default.LocationOn
        "idle_alarm" -> Icons.Default.HourglassBottom
        "movement_detection" -> Icons.Default.DirectionsCar
        "off_hours_usage" -> Icons.Default.Schedule
        "ignition_on" -> Icons.Default.VpnKey
        "ignition_off" -> Icons.Default.PowerOff
        else -> Icons.Default.Notifications
    }

    val color: Color get() = when (alarmType) {
        "speed_violation" -> Color(0xFFEF4444)
        "geofence_alarm" -> Color(0xFF22C55E)
        "idle_alarm" -> Color(0xFFF59E0B)
        "movement_detection" -> Color(0xFFF97316)
        "off_hours_usage" -> AppColors.Indigo
        "ignition_on" -> Color(0xFF22C55E)
        "ignition_off" -> Color(0xFFEF4444)
        else -> AppColors.Indigo
    }

    val typeLabel: String get() = when (alarmType) {
        "speed_violation" -> "Hız İhlali"
        "idle_alarm" -> "Rölanti"
        "movement_detection" -> "Hareket Algılama"
        "off_hours_usage" -> "Mesai Dışı Kullanım"
        "geofence_alarm" -> "Bölge Alarmı"
        "ignition_on" -> "Kontak Açılma"
        "ignition_off" -> "Kontak Kapanma"
        else -> alarmType.replace("_", " ").replaceFirstChar { it.uppercase() }
    }

    val statusLabel: String get() = when (status) {
        "active" -> "Aktif"
        "paused" -> "Duraklatıldı"
        "draft" -> "Taslak"
        "archived" -> "Arşiv"
        else -> status.replaceFirstChar { it.uppercase() }
    }

    val statusColor: Color get() = when (status) {
        "active" -> Color(0xFF22C55E)
        "paused" -> Color(0xFFF59E0B)
        "draft" -> Color.Gray
        "archived" -> Color(0xFF6B7280)
        else -> Color.Gray
    }

    val channelList: List<String> get() = channelCodes.split(",").map { it.trim() }.filter { it.isNotEmpty() }

    val formattedDate: String get() {
        if (createdAt.length < 10) return createdAt
        return try {
            val dateParts = createdAt.take(10).split("-")
            val months = arrayOf("", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara")
            val month = dateParts[1].toIntOrNull() ?: 0
            val day = dateParts[2]
            "$day ${months[month.coerceIn(0, 12)]}"
        } catch (_: Exception) { createdAt }
    }

    companion object {
        fun from(json: JSONObject): AlarmSet = try {
            AlarmSet(
                id = json.optInt("id"),
                name = json.optString("name", ""),
                description = json.optString("description", "").let { if (it == "null" || it.isEmpty()) null else it },
                alarmType = json.optString("alarm_type", ""),
                status = json.optString("status", "draft"),
                evaluationMode = json.optString("evaluation_mode", "live"),
                sourceMode = json.optString("source_mode", "derived"),
                cooldownSec = json.optInt("cooldown_sec", 300),
                isActive = json.optBoolean("is_active", false),
                conditionSummary = json.optString("condition_summary", ""),
                channelCodes = json.optString("channel_codes", ""),
                targetCount = json.optInt("target_count", 0),
                channelCount = json.optInt("channel_count", 0),
                recipientCount = json.optInt("recipient_count", 0),
                createdAt = json.optString("created_at", "")
            )
        } catch (_: Exception) {
            AlarmSet(0, "", null, "", "draft", "live", "derived", 300, false, "", "", 0, 0, 0, "")
        }
    }

    val isHiddenMobileIgnitionRule: Boolean
        get() = name.startsWith(MOBILE_PRIVATE_IGNITION_ALARM_PREFIX)
}

// MARK: - Catalog models
data class AlarmCatalogVehicle(val id: Int, val assignmentId: Int, val label: String, val plate: String)
data class AlarmCatalogRecipient(val id: Int, val name: String, val email: String)
data class AlarmCatalogGeofence(val id: Int, val name: String)
data class AlarmTypeOption(val value: String, val label: String, val description: String)

data class AlarmCatalog(
    val vehicles: List<AlarmCatalogVehicle>,
    val recipients: List<AlarmCatalogRecipient>,
    val geofences: List<AlarmCatalogGeofence>,
    val types: List<AlarmTypeOption>,
    val defaults: JSONObject?
) {
    companion object {
        fun from(json: JSONObject): AlarmCatalog {
            val catalog = json.optJSONObject("catalog") ?: json
            val vehicles = mutableListOf<AlarmCatalogVehicle>()
            val assignments = catalog.optJSONArray("assignments")
            if (assignments != null) {
                for (i in 0 until assignments.length()) {
                    val v = assignments.getJSONObject(i)
                    vehicles.add(AlarmCatalogVehicle(
                        id = v.optInt("device_id", v.optInt("id")),
                        assignmentId = v.optInt("id"),
                        label = v.optString("label", ""),
                        plate = v.optString("plate", "")
                    ))
                }
            }
            val recipients = mutableListOf<AlarmCatalogRecipient>()
            val recipArr = catalog.optJSONArray("recipients")
            if (recipArr != null) {
                for (i in 0 until recipArr.length()) {
                    val r = recipArr.getJSONObject(i)
                    recipients.add(AlarmCatalogRecipient(r.optInt("id"), r.optString("name", ""), r.optString("email", "")))
                }
            }
            val geofences = mutableListOf<AlarmCatalogGeofence>()
            val geoArr = catalog.optJSONArray("geofences")
            if (geoArr != null) {
                for (i in 0 until geoArr.length()) {
                    val g = geoArr.getJSONObject(i)
                    geofences.add(AlarmCatalogGeofence(g.optInt("id"), g.optString("name", "")))
                }
            }
            val types = mutableListOf<AlarmTypeOption>()
            val typeArr = catalog.optJSONArray("types")
            if (typeArr != null) {
                for (i in 0 until typeArr.length()) {
                    val t = typeArr.getJSONObject(i)
                    types.add(AlarmTypeOption(t.optString("value"), t.optString("label"), t.optString("description", "")))
                }
            }
            return AlarmCatalog(vehicles, recipients, geofences, types, json.optJSONObject("defaults"))
        }
    }
}

// MARK: - Alarm Types
private val ALARM_TYPES = listOf(
    "overspeed" to "Hız Aşımı",
    "harsh_brake" to "Sert Fren",
    "harsh_acceleration" to "Sert Hızlanma",
    "idle" to "Rölanti",
    "geofence_enter" to "Bölgeye Giriş",
    "geofence_exit" to "Bölgeden Çıkış",
    "disconnect" to "Bağlantı Koptu",
    "sos" to "SOS / Panik",
    "tow" to "Çekici",
    "power_cut" to "Güç Kesildi",
)

// MARK: - Alarms Screen
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlarmsScreen(
    initialSearchText: String = "",
    autoOpenCreate: Boolean = false,
    preSelectedPlate: String = "",
    initialAlarmEvent: AlarmEvent? = null
) {
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // Tab state — auto-switch to Alarm Kuralları tab when creating
    var selectedTab by remember { mutableIntStateOf(if (autoOpenCreate) 1 else 0) }

    // Search — initialize with passed text (e.g. from VehicleDetail "Tümünü Gör")
    var searchText by remember { mutableStateOf(initialSearchText) }

    // Detail sheets
    var selectedAlarm by remember { mutableStateOf<AlarmEvent?>(null) }
    var selectedRule by remember { mutableStateOf<AlarmSet?>(null) }
    var showCreateSheet by remember { mutableStateOf(autoOpenCreate) }
    var createPrePlate by remember { mutableStateOf(preSelectedPlate) }
    var isRefreshing by remember { mutableStateOf(false) }

    // State
    var alarms by remember { mutableStateOf(listOf<AlarmEvent>()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var currentPage by remember { mutableIntStateOf(1) }
    var lastPage by remember { mutableIntStateOf(1) }
    var totalCount by remember { mutableIntStateOf(0) }

    // Alarm Sets state
    var alarmSets by remember { mutableStateOf(listOf<AlarmSet>()) }
    var isLoadingSets by remember { mutableStateOf(false) }
    var setsError by remember { mutableStateOf<String?>(null) }
    var catalog by remember { mutableStateOf<AlarmCatalog?>(null) }
    var actionLoading by remember { mutableStateOf<Int?>(null) }  // which set ID is being acted on

    // Filtreler
    var selectedType by remember { mutableStateOf<String?>(null) }
    var showFilterSheet by remember { mutableStateOf(false) }

    val hasActiveFilters = selectedType != null

    // API çağrısı — Alarm Events
    suspend fun fetchAlarms(page: Int = 1, append: Boolean = false) {
        if (isLoading) return
        isLoading = true
        errorMessage = null

        var path = "/api/mobile/alarms?page=$page&per_page=20"
        selectedType?.let { path += "&type=$it" }

        try {
            val json = APIService.get(path)
            val dataArr = json.optJSONArray("data")
            val pagination = json.optJSONObject("pagination")

            val newAlarms = mutableListOf<AlarmEvent>()
            if (dataArr != null) {
                for (i in 0 until dataArr.length()) {
                    newAlarms.add(AlarmEvent.from(dataArr.getJSONObject(i), i))
                }
            }

            if (append) {
                alarms = alarms + newAlarms
            } else {
                alarms = newAlarms
            }

            currentPage = pagination?.optInt("current_page", page) ?: page
            lastPage = pagination?.optInt("last_page", 1) ?: 1
            totalCount = pagination?.optInt("total", alarms.size) ?: alarms.size
        } catch (e: Exception) {
            if (!append) {
                errorMessage = e.message ?: "Alarmlar yüklenemedi"
            }
        }

        isLoading = false
    }

    // API çağrısı — Alarm Sets
    suspend fun fetchAlarmSets() {
        if (isLoadingSets) return
        isLoadingSets = true
        setsError = null

        try {
            val json = APIService.get("/api/mobile/alarm-sets/")
            val dataArr = json.optJSONArray("data")
            val sets = mutableListOf<AlarmSet>()
            if (dataArr != null) {
                for (i in 0 until dataArr.length()) {
                    sets.add(AlarmSet.from(dataArr.getJSONObject(i)))
                }
            }
            alarmSets = sets
        } catch (e: Exception) {
            setsError = "Alarm kuralları yüklenemedi"
        }

        isLoadingSets = false
    }

    // Fetch catalog (for create form)
    suspend fun fetchCatalog() {
        try {
            val json = APIService.get("/api/mobile/alarm-sets/catalog")
            catalog = AlarmCatalog.from(json)
        } catch (_: Exception) { }
    }

    suspend fun refreshCurrentTab() {
        isRefreshing = true
        if (selectedTab == 0) {
            fetchAlarms()
        } else {
            fetchAlarmSets()
            fetchCatalog()
        }
        isRefreshing = false
    }

    // Activate / Pause / Archive actions
    suspend fun toggleAlarmSet(set: AlarmSet) {
        actionLoading = set.id
        try {
            val action = if (set.status == "active") "pause" else "activate"
            APIService.post("/api/mobile/alarm-sets/${set.id}/$action")
            fetchAlarmSets()
        } catch (_: Exception) { }
        actionLoading = null
    }

    suspend fun archiveAlarmSet(set: AlarmSet) {
        actionLoading = set.id
        try {
            APIService.post("/api/mobile/alarm-sets/${set.id}/archive")
            fetchAlarmSets()
        } catch (_: Exception) { }
        actionLoading = null
    }

    // İlk yükleme
    LaunchedEffect(Unit) {
        fetchAlarms()
        fetchAlarmSets()
        fetchCatalog()
        if (initialAlarmEvent != null && !autoOpenCreate) {
            selectedTab = 0
            selectedAlarm = initialAlarmEvent
        }
    }

    LaunchedEffect(initialAlarmEvent, alarms) {
        if (initialAlarmEvent != null && !autoOpenCreate && selectedAlarm == null) {
            selectedTab = 0
            selectedAlarm = alarms.firstOrNull { it.id == initialAlarmEvent.id } ?: initialAlarmEvent
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Alarmlar", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                        Text("İzleme / Alarmlar", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                    }
                },
                actions = {
                    // Filtre butonu - sadece Gelen Alarmlar tabında göster
                    if (selectedTab == 0) {
                        IconButton(onClick = { showFilterSheet = true }) {
                            Icon(
                                if (hasActiveFilters) Icons.Default.FilterAlt else Icons.Default.FilterList,
                                "Filtreler",
                                tint = if (hasActiveFilters) AppColors.Indigo else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { innerPadding ->
        // Filtered lists
        val filteredAlarms = if (searchText.isBlank()) alarms else {
            val q = searchText.lowercase()
            alarms.filter {
                it.typeLabel.lowercase().contains(q) ||
                it.plate.lowercase().contains(q) ||
                it.vehicleName.lowercase().contains(q) ||
                it.code.lowercase().contains(q)
            }
        }

        val visibleRules = alarmSets.filterNot { it.isHiddenMobileIgnitionRule }
        val filteredRules = if (searchText.isBlank()) visibleRules else {
            val q = searchText.lowercase()
            visibleRules.filter {
                it.name.lowercase().contains(q) ||
                it.typeLabel.lowercase().contains(q) ||
                it.conditionSummary.lowercase().contains(q)
            }
        }

        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = { scope.launch { refreshCurrentTab() } },
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Tab Selector
                TabSelector(selectedTab = selectedTab, onTabSelected = {
                    selectedTab = it
                    searchText = ""
                })

                // Search Bar
                SearchBar(
                    text = searchText,
                    onTextChange = { searchText = it },
                    placeholder = if (selectedTab == 0) "Alarm ara (plaka, tür, açıklama...)" else "Kural ara (isim, tür, araç...)"
                )

                if (selectedTab == 0) {
                    if (hasActiveFilters) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(MaterialTheme.colorScheme.surface)
                                .horizontalScroll(rememberScrollState())
                                .padding(horizontal = 16.dp, vertical = 8.dp),
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            selectedType?.let { type ->
                                FilterChip(label = ALARM_TYPES.firstOrNull { it.first == type }?.second ?: type) {
                                    selectedType = null
                                    scope.launch { fetchAlarms() }
                                }
                            }
                            TextButton(
                                onClick = {
                                    selectedType = null
                                    scope.launch { fetchAlarms() }
                                },
                                contentPadding = PaddingValues(horizontal = 8.dp)
                            ) {
                                Text("Temizle", fontSize = 11.sp, color = Color.Red)
                            }
                        }
                    }

                    when {
                        isLoading && alarms.isEmpty() -> AlarmEventsSkeletonList()
                        errorMessage != null && alarms.isEmpty() -> ErrorContent(errorMessage!!) {
                            scope.launch { refreshCurrentTab() }
                        }
                        alarms.isEmpty() -> EmptyContent(hasActiveFilters) {
                            selectedType = null
                            scope.launch { fetchAlarms() }
                        }
                        else -> {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    "${filteredAlarms.size} alarm",
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                                )
                                Spacer(Modifier.weight(1f))
                                if (isLoading && searchText.isBlank()) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(14.dp),
                                        strokeWidth = 2.dp,
                                        color = AppColors.Indigo
                                    )
                                }
                            }

                            LazyColumn(
                                state = listState,
                                modifier = Modifier.fillMaxSize(),
                                contentPadding = PaddingValues(bottom = 20.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                items(filteredAlarms, key = { it.id }) { alarm ->
                                    AlarmCard(alarm, onClick = { selectedAlarm = alarm })
                                }

                                if (currentPage < lastPage && searchText.isBlank()) {
                                    item {
                                        LaunchedEffect(Unit) {
                                            fetchAlarms(currentPage + 1, append = true)
                                        }
                                        Row(
                                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                                            horizontalArrangement = Arrangement.Center,
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                                            Spacer(Modifier.width(8.dp))
                                            Text("Yükleniyor...", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    AlarmRulesTab(
                        filteredRules = filteredRules,
                        isLoading = isLoadingSets,
                        error = setsError,
                        onRuleClick = { selectedRule = it },
                        onNewRule = { showCreateSheet = true },
                        onRetry = { scope.launch { refreshCurrentTab() } }
                    )
                }
            }
        }
    }

    // Alarm Detail Bottom Sheet
    selectedAlarm?.let { alarm ->
        AlarmDetailSheet(alarm = alarm, onDismiss = { selectedAlarm = null })
    }

    // Rule Detail Bottom Sheet
    selectedRule?.let { rule ->
        RuleDetailSheet(
            rule = rule,
            actionLoading = actionLoading == rule.id,
            onDismiss = { selectedRule = null },
            onToggle = { scope.launch { toggleAlarmSet(rule); selectedRule = null } },
            onArchive = { scope.launch { archiveAlarmSet(rule); selectedRule = null } }
        )
    }

    // Create Alarm Set Sheet
    if (showCreateSheet) {
        CreateAlarmSetSheet(
            catalog = catalog,
            preSelectedPlate = createPrePlate,
            onDismiss = { showCreateSheet = false; createPrePlate = "" },
            onCreated = {
                showCreateSheet = false
                createPrePlate = ""
                scope.launch { fetchAlarmSets() }
            }
        )
    }

    // Filtre Bottom Sheet
    if (showFilterSheet) {
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            containerColor = MaterialTheme.colorScheme.surface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 32.dp)
            ) {
                Text("Alarm Türü", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(12.dp))

                // Tümü
                FilterRow("Tümü", selectedType == null) {
                    selectedType = null
                }

                ALARM_TYPES.forEach { (key, label) ->
                    FilterRow(label, selectedType == key) {
                        selectedType = key
                    }
                }

                Spacer(Modifier.height(16.dp))

                Button(
                    onClick = {
                        showFilterSheet = false
                        scope.launch { fetchAlarms() }
                    },
                    modifier = Modifier.fillMaxWidth().height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.onSurface),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("Uygula", fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

// MARK: - Search Bar
@Composable
private fun SearchBar(text: String, onTextChange: (String) -> Unit, placeholder: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .padding(bottom = 4.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 4.dp)
    ) {
        Icon(Icons.Default.Search, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(8.dp))
        BasicTextField(
            value = text,
            onValueChange = onTextChange,
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(
                fontSize = 13.sp,
                color = MaterialTheme.colorScheme.onSurface
            ),
            decorationBox = { innerTextField ->
                Box(modifier = Modifier.weight(1f).padding(vertical = 6.dp)) {
                    if (text.isEmpty()) {
                        Text(placeholder, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                    }
                    innerTextField()
                }
            },
            modifier = Modifier.weight(1f)
        )
        if (text.isNotEmpty()) {
            IconButton(onClick = { onTextChange("") }, modifier = Modifier.size(24.dp)) {
                Icon(Icons.Default.Close, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
            }
        }
    }
}

// MARK: - Tab Selector
@Composable
private fun TabSelector(selectedTab: Int, onTabSelected: (Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp))
            .padding(4.dp)
    ) {
        // Tab 0: Gelen Alarmlar
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selectedTab == 0) MaterialTheme.colorScheme.onSurface else Color.Transparent)
                .clickable { onTabSelected(0) }
                .padding(vertical = 10.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.NotificationsActive, null, tint = if (selectedTab == 0) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
                Text("Gelen Alarmlar", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (selectedTab == 0) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
            }
        }

        // Tab 1: Alarm Kuralları
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selectedTab == 1) MaterialTheme.colorScheme.onSurface else Color.Transparent)
                .clickable { onTabSelected(1) }
                .padding(vertical = 10.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Settings, null, tint = if (selectedTab == 1) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
                Text("Alarm Kuralları", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (selectedTab == 1) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
            }
        }
    }
}

// MARK: - Alarm Rules Tab
@Composable
private fun AlarmRulesTab(
    filteredRules: List<AlarmSet>,
    isLoading: Boolean,
    error: String?,
    onRuleClick: (AlarmSet) -> Unit,
    onNewRule: () -> Unit,
    onRetry: () -> Unit
) {
    when {
        isLoading && filteredRules.isEmpty() -> AlarmRulesSkeletonList()
        error != null && filteredRules.isEmpty() -> ErrorContent(error) { onRetry() }
        else -> {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = 20.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // Yeni Kural Ekle
                item {
                    NewRuleButton(onClick = onNewRule)
                }

                // Header
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "${filteredRules.size} kural tanımlı",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                        )
                    }
                }

                if (filteredRules.isEmpty() && !isLoading) {
                    item {
                        Box(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 40.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Default.Settings, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f), modifier = Modifier.size(40.dp))
                                Spacer(Modifier.height(8.dp))
                                Text("Henüz alarm kuralı yok", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                Text("Yukarıdaki butona tıklayarak yeni kural ekleyin", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
                            }
                        }
                    }
                }

                items(filteredRules, key = { it.id }) { rule ->
                    AlarmSetCard(rule, onClick = { onRuleClick(rule) })
                }
            }
        }
    }
}

// MARK: - New Rule Button (Kart tarzı)
@Composable
private fun NewRuleButton(onClick: () -> Unit = {}) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Indigo.copy(alpha = 0.04f))
            .border(1.dp, AppColors.Indigo.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 10.dp)
    ) {
        // İkon
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(AppColors.Indigo.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Default.Add, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
        }

        Spacer(Modifier.width(10.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text("Yeni Alarm Kuralı Ekle", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Indigo)
            Text("Araçlarınız için özel alarm kuralı tanımlayın", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
        }

        Icon(Icons.Default.ChevronRight, null, tint = AppColors.Indigo.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
    }
}

// MARK: - Alarm Set Card
@Composable
private fun AlarmSetCard(rule: AlarmSet, onClick: () -> Unit = {}) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface)
            .clickable { onClick() }
            .padding(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // İkon
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(rule.color.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(rule.icon, null, tint = rule.color, modifier = Modifier.size(16.dp))
            }

            // İsim ve tür
            Column(modifier = Modifier.weight(1f)) {
                Text(rule.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                Text(rule.typeLabel, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
            }

            // Status badge
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(rule.statusColor.copy(alpha = 0.1f))
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(rule.statusColor)
                )
                Text(
                    rule.statusLabel,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = rule.statusColor
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        // Detaylar
        Column(
            verticalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.padding(start = 48.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Warning, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f), modifier = Modifier.size(12.dp))
                Text("Koşul: ${rule.conditionSummary}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.DirectionsCar, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f), modifier = Modifier.size(12.dp))
                Text("${rule.targetCount} araç", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                Spacer(Modifier.width(8.dp))
                // Channels
                rule.channelList.forEach { ch ->
                    val chIcon = when (ch) {
                        "email" -> Icons.Default.Email
                        "sms" -> Icons.Default.Sms
                        "push" -> Icons.Default.Notifications
                        else -> Icons.Default.Notifications
                    }
                    Icon(chIcon, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f), modifier = Modifier.size(12.dp))
                }
            }
        }
    }
}

// MARK: - Alarm Card
@Composable
private fun AlarmCard(alarm: AlarmEvent, onClick: () -> Unit = {}) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface)
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // İkon
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(alarm.color.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(alarm.icon, null, tint = alarm.color, modifier = Modifier.size(18.dp))
        }

        // Bilgi
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    alarm.typeLabel,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    alarm.formattedDate,
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
                )
            }

            Spacer(Modifier.height(3.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                // Plaka
                Text(
                    alarm.plate.ifEmpty { alarm.vehicleName },
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.Indigo,
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(AppColors.Indigo.copy(alpha = 0.08f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )

                if (alarm.speed > 0) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(2.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Speed, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(11.dp))
                        Text("${alarm.speed} km/s", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                    }
                }
            }

            // Status badge + description
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                // Aktif/Kapandı badge
                Text(
                    alarm.statusLabel,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Bold,
                    color = alarm.statusColor,
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .background(alarm.statusColor.copy(alpha = 0.10f))
                        .padding(horizontal = 6.dp, vertical = 2.dp)
                )

                val displayText = alarm.description.ifEmpty { alarm.code }
                if (displayText.isNotEmpty()) {
                    Text(
                        displayText,
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f, fill = false)
                    )
                }
            }
        }

        // Ok
        Icon(
            Icons.Default.ChevronRight, null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
            modifier = Modifier.size(16.dp)
        )
    }
}

// MARK: - Filter Chip
@Composable
private fun FilterChip(label: String, onRemove: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Indigo.copy(alpha = 0.08f))
            .padding(horizontal = 10.dp, vertical = 5.dp)
    ) {
        Text(label, fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.Indigo)
        Spacer(Modifier.width(4.dp))
        Icon(
            Icons.Default.Close, null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            modifier = Modifier.size(14.dp).clickable { onRemove() }
        )
    }
}

// MARK: - Filter Row
@Composable
private fun FilterRow(label: String, isSelected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            label,
            fontSize = 14.sp,
            color = if (isSelected) AppColors.Indigo else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            modifier = Modifier.weight(1f)
        )
        if (isSelected) {
            Icon(Icons.Default.Check, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
        }
    }
}

// MARK: - Loading Content
@Composable
private fun LoadingContent() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(color = AppColors.Indigo)
            Spacer(Modifier.height(16.dp))
            Text("Alarmlar yükleniyor...", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
        }
    }
}

// MARK: - Error Content
@Composable
private fun ErrorContent(message: String, onRetry: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.Warning, null, tint = Color(0xFFF97316), modifier = Modifier.size(44.dp))
            Spacer(Modifier.height(12.dp))
            Text("Bir hata oluştu", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.height(4.dp))
            Text(message, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.padding(horizontal = 40.dp))
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = onRetry,
                colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo),
                shape = RoundedCornerShape(8.dp)
            ) {
                Text("Tekrar Dene", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

// MARK: - Empty Content
@Composable
private fun EmptyContent(hasFilters: Boolean, onClearFilters: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Default.NotificationsOff, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f), modifier = Modifier.size(48.dp))
            Spacer(Modifier.height(12.dp))
            Text("Alarm Bulunamadı", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.height(4.dp))
            Text(
                "Seçili filtrelere uygun alarm kaydı yok.\nFiltrelerinizi değiştirerek tekrar deneyebilirsiniz.",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                modifier = Modifier.padding(horizontal = 40.dp),
                lineHeight = 18.sp
            )
            if (hasFilters) {
                Spacer(Modifier.height(12.dp))
                TextButton(onClick = onClearFilters) {
                    Text("Filtreleri Temizle", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Indigo)
                }
            }
        }
    }
}

// MARK: - Alarm Detail Sheet
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AlarmDetailSheet(alarm: AlarmEvent, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 32.dp)
        ) {
            // Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(alarm.color.copy(alpha = 0.04f))
                    .padding(vertical = 24.dp)
            ) {
                Box(
                    modifier = Modifier.size(60.dp).clip(CircleShape).background(alarm.color.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(alarm.icon, null, tint = alarm.color, modifier = Modifier.size(28.dp))
                }
                Spacer(Modifier.height(12.dp))
                Text(alarm.typeLabel, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(4.dp))
                Text(alarm.formattedFullDate, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
            }

            Spacer(Modifier.height(8.dp))

            // Details
            DetailRow(icon = Icons.Default.DirectionsCar, title = "Araç", value = if (alarm.plate.isNotEmpty()) "${alarm.plate} — ${alarm.vehicleName}" else alarm.vehicleName)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Tag, title = "IMEI", value = alarm.imei)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Speed, title = "Hız", value = if (alarm.speed > 0) "${alarm.speed} km/s" else "—")
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Description, title = "Açıklama", value = alarm.description.ifEmpty { alarm.code }.ifEmpty { "—" })
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Circle, title = "Durum", value = alarm.statusLabel)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.LocationOn, title = "Konum", value = String.format("%.4f, %.4f", alarm.lat, alarm.lng))
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.CalendarMonth, title = "Tarih", value = alarm.formattedFullDate)

            // Map - Alarm konumu
            if (alarm.lat != 0.0 && alarm.lng != 0.0) {
                Spacer(Modifier.height(12.dp))

                Column(modifier = Modifier.padding(horizontal = 16.dp)) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.padding(bottom = 8.dp)
                    ) {
                        Icon(Icons.Default.Map, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
                        Text("Alarm Konumu", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                    }

                    val context = LocalContext.current
                    Configuration.getInstance().userAgentValue = context.packageName

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                            .clip(RoundedCornerShape(12.dp))
                    ) {
                        AndroidView(
                            factory = { ctx ->
                                MapView(ctx).apply {
                                    setTileSource(TileSourceFactory.MAPNIK)
                                    setMultiTouchControls(true)
                                    controller.setZoom(15.0)
                                    controller.setCenter(GeoPoint(alarm.lat, alarm.lng))
                                    zoomController.setVisibility(
                                        org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER
                                    )

                                    // Alarm marker
                                    val marker = Marker(this)
                                    marker.position = GeoPoint(alarm.lat, alarm.lng)
                                    marker.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                                    marker.title = alarm.typeLabel
                                    marker.snippet = alarm.plate
                                    marker.infoWindow = null

                                    // Alarm renk ikonu
                                    val key = alarm.alarmKey
                                    val alarmColor = when {
                                        key.contains("overspeed", true) || key.contains("sos", true) -> android.graphics.Color.rgb(239, 68, 68)
                                        key.contains("brake", true) || key.contains("disconnect", true) -> android.graphics.Color.rgb(249, 115, 22)
                                        key.contains("idle", true) -> android.graphics.Color.rgb(245, 158, 11)
                                        key.contains("geofence", true) || key.contains("GF_", false) -> android.graphics.Color.rgb(34, 197, 94)
                                        key.contains("T_MOVEMENT", true) || key.contains("hareket", true) -> android.graphics.Color.rgb(249, 115, 22)
                                        key.contains("T_TOWING", true) || key.contains("çekme", true) || key.contains("taşıma", true) -> android.graphics.Color.rgb(239, 68, 68)
                                        else -> android.graphics.Color.rgb(99, 102, 241)
                                    }

                                    val density = ctx.resources.displayMetrics.density
                                    val pinSize = (40 * density).toInt()
                                    val bitmap = android.graphics.Bitmap.createBitmap(pinSize, pinSize, android.graphics.Bitmap.Config.ARGB_8888)
                                    val canvas = android.graphics.Canvas(bitmap)
                                    val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = alarmColor }
                                    val borderPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                                        color = android.graphics.Color.WHITE
                                        style = android.graphics.Paint.Style.STROKE
                                        strokeWidth = 3f * density
                                    }
                                    canvas.drawCircle(pinSize / 2f, pinSize / 2f, pinSize / 2f - 2f * density, paint)
                                    canvas.drawCircle(pinSize / 2f, pinSize / 2f, pinSize / 2f - 2f * density, borderPaint)
                                    // Alarm icon
                                    val iconPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                                        color = android.graphics.Color.WHITE
                                        textSize = 18f * density
                                        textAlign = android.graphics.Paint.Align.CENTER
                                    }
                                    canvas.drawText("⚠", pinSize / 2f, pinSize / 2f + 7f * density, iconPaint)
                                    marker.icon = android.graphics.drawable.BitmapDrawable(ctx.resources, bitmap)
                                    overlays.add(marker)
                                }
                            },
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    // Konuma Git button
                    val navContext = LocalContext.current
                    Spacer(Modifier.height(10.dp))
                    Button(
                        onClick = {
                            openMapsDirectionsAlarm(navContext, alarm.lat, alarm.lng, alarm.plate.ifEmpty { alarm.vehicleName })
                        },
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                        shape = RoundedCornerShape(10.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo)
                    ) {
                        Icon(Icons.Default.Navigation, null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Konuma Git", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                }

                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

// MARK: - Rule Detail Sheet
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RuleDetailSheet(
    rule: AlarmSet,
    actionLoading: Boolean,
    onDismiss: () -> Unit,
    onToggle: () -> Unit,
    onArchive: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 32.dp)
        ) {
            // Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(rule.color.copy(alpha = 0.04f))
                    .padding(vertical = 24.dp)
            ) {
                Box(
                    modifier = Modifier.size(60.dp).clip(CircleShape).background(rule.color.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(rule.icon, null, tint = rule.color, modifier = Modifier.size(28.dp))
                }
                Spacer(Modifier.height(12.dp))
                Text(rule.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                if (rule.description != null) {
                    Spacer(Modifier.height(4.dp))
                    Text(rule.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                }
                Spacer(Modifier.height(8.dp))
                // Status badge
                Row(
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(rule.statusColor.copy(alpha = 0.1f))
                        .padding(horizontal = 12.dp, vertical = 5.dp)
                ) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(rule.statusColor))
                    Text(
                        rule.statusLabel,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = rule.statusColor
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Details
            DetailRow(icon = Icons.Default.Sell, title = "Alarm Türü", value = rule.typeLabel)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Warning, title = "Koşul", value = rule.conditionSummary.ifEmpty { "—" })
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.DirectionsCar, title = "Hedef Araçlar", value = "${rule.targetCount} araç")
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Notifications, title = "Bildirim Kanalları", value = rule.channelList.joinToString(", ") {
                when (it) { "email" -> "E-posta"; "sms" -> "SMS"; "push" -> "Mobil Bildirim"; else -> it }
            }.ifEmpty { "—" })
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.People, title = "Alıcılar", value = "${rule.recipientCount} kişi")
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Timer, title = "Bekleme Süresi", value = "${rule.cooldownSec / 60} dk")
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Visibility, title = "Değerlendirme", value = when(rule.evaluationMode) {
                "live" -> "Canlı Alarm"; "shadow" -> "İzleme Modu"; else -> rule.evaluationMode
            })
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = MaterialTheme.colorScheme.outline.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.CalendarMonth, title = "Oluşturulma", value = rule.formattedDate)

            // Actions
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                // Activate/Pause toggle
                if (rule.status != "archived") {
                    Button(
                        onClick = onToggle,
                        enabled = !actionLoading,
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (rule.status == "active") Color(0xFFF59E0B) else Color(0xFF22C55E)
                        ),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        if (actionLoading) {
                            CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp, color = Color.White)
                        } else {
                            Icon(
                                if (rule.status == "active") Icons.Default.Pause else Icons.Default.PlayArrow,
                                null, modifier = Modifier.size(16.dp)
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(
                                if (rule.status == "active") "Duraklatır" else "Aktifleştir",
                                fontWeight = FontWeight.SemiBold, fontSize = 14.sp
                            )
                        }
                    }
                }

                // Archive/Delete
                if (rule.status != "archived") {
                    OutlinedButton(
                        onClick = onArchive,
                        enabled = !actionLoading,
                        modifier = Modifier.fillMaxWidth().height(44.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.Red),
                        border = BorderStroke(1.dp, Color.Red.copy(alpha = 0.3f)),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(Icons.Default.Archive, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Arşivle", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    }
                }
            }
        }
    }
}

// MARK: - Create Alarm Set Sheet (Modern Step Wizard)
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateAlarmSetSheet(
    catalog: AlarmCatalog?,
    preSelectedPlate: String = "",
    onDismiss: () -> Unit,
    onCreated: () -> Unit
) {
    val scope = rememberCoroutineScope()

    // Step state (1-based: 1=İsim&Tür, 2=Araçlar, 3=Koşullar, 4=Bildirim)
    var currentStep by remember { mutableIntStateOf(1) }

    // Form state
    var name by remember { mutableStateOf("") }
    var selectedType by remember { mutableStateOf("speed_violation") }
    var selectedVehicles by remember { mutableStateOf(setOf<Int>()) }
    var selectedChannels by remember { mutableStateOf(setOf("push")) }
    var selectedRecipients by remember { mutableStateOf(setOf<Int>()) }
    var selectedGeofence by remember { mutableStateOf<Int?>(null) }
    var speedLimit by remember { mutableStateOf("80") }
    var idleAfterSec by remember { mutableStateOf("300") }
    var isSaving by remember { mutableStateOf(false) }
    var errorMsg by remember { mutableStateOf<String?>(null) }
    var vehicleSearch by remember { mutableStateOf("") }

    // Pre-select vehicle by plate
    LaunchedEffect(catalog, preSelectedPlate) {
        if (preSelectedPlate.isNotEmpty() && catalog != null) {
            val match = catalog.vehicles.firstOrNull { it.plate.equals(preSelectedPlate, true) || it.label.contains(preSelectedPlate, true) }
            if (match != null) {
                selectedVehicles = setOf(match.assignmentId)
            }
        }
        catalog?.recipients?.firstOrNull()?.let { selectedRecipients = setOf(it.id) }
    }

    suspend fun save() {
        if (name.isBlank()) { errorMsg = "Kural adı gerekli"; return }
        if (selectedVehicles.isEmpty()) { errorMsg = "En az bir araç seçin"; currentStep = 2; return }
        if (selectedChannels.isEmpty()) { errorMsg = "En az bir bildirim kanalı seçin"; return }
        if (selectedRecipients.isEmpty()) { errorMsg = "En az bir alıcı seçin"; return }

        isSaving = true
        errorMsg = null

        val body = JSONObject().apply {
            put("name", name)
            put("alarm_type", selectedType)
            put("status", "active")
            put("evaluation_mode", "live")
            put("source_mode", if (selectedType == "speed_violation") "existing" else "derived")
            put("cooldown_sec", 300)
            put("is_active", true)
            put("condition_require_ignition", true)
            val targets = org.json.JSONArray()
            selectedVehicles.forEach { assignmentId ->
                targets.put(JSONObject().apply { put("scope", "assignment"); put("id", assignmentId) })
            }
            put("targets", targets)
            val channels = org.json.JSONArray()
            selectedChannels.forEach { channels.put(it) }
            put("channels", channels)
            val recipients = org.json.JSONArray()
            selectedRecipients.forEach { recipients.put(it) }
            put("recipient_ids", recipients)
            when (selectedType) {
                "speed_violation" -> {
                    put("condition_speed_limit_kmh", speedLimit.toIntOrNull() ?: 80)
                    put("condition_speed_duration_sec", 5)
                }
                "idle_alarm" -> {
                    put("condition_idle_after_sec", idleAfterSec.toIntOrNull() ?: 300)
                    put("condition_speed_threshold_kmh", 0)
                }
                "geofence_alarm" -> {
                    selectedGeofence?.let { put("condition_geofence_id", it) }
                    put("condition_geofence_trigger", "both")
                }
                "off_hours_usage" -> {
                    put("condition_start_local", "08:00")
                    put("condition_end_local", "18:00")
                    put("condition_timezone", "Europe/Istanbul")
                    put("condition_min_speed_kmh", 1)
                    val days = org.json.JSONArray()
                    listOf(1,2,3,4,5).forEach { days.put(it) }
                    put("condition_days", days)
                }
            }
        }

        try {
            APIService.post("/api/mobile/alarm-sets/", body)
            onCreated()
        } catch (e: Exception) {
            errorMsg = "Kayıt başarısız: ${e.message}"
        }
        isSaving = false
    }

    val typeOptions = catalog?.types ?: listOf(
        AlarmTypeOption("speed_violation", "Hız İhlali", "Belirlenen hız limitini aşıldığında bildirim alın"),
        AlarmTypeOption("idle_alarm", "Rölanti", "Araç belirli süreden fazla rölantide kaldığında uyar"),
        AlarmTypeOption("movement_detection", "Hareket Algılama", "Park halindeki aracın hareket etmesinde uyar"),
        AlarmTypeOption("off_hours_usage", "Mesai Dışı Kullanım", "Mesai saatleri dışında kullanımda uyar"),
        AlarmTypeOption("geofence_alarm", "Bölge Alarmı", "Bölgeye giriş/çıkışta bildirim alın"),
        AlarmTypeOption("ignition_on", "Kontak Açılma", "Araç kontağı açıldığında bildirim alın"),
        AlarmTypeOption("ignition_off", "Kontak Kapanma", "Araç kontağı kapandığında bildirim alın")
    )

    val stepLabels = listOf("İsim & Tür", "Araçlar", "Koşullar", "Bildirim")

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.background,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
        ) {
            // ── Header ──
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.onSurface)
                    .padding(horizontal = 20.dp, vertical = 16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Yeni Alarm Oluştur", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        Text("Adım adım alarm kurun — çok kolay!", fontSize = 12.sp, color = Color.White.copy(alpha = 0.7f))
                    }
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, null, tint = Color.White.copy(alpha = 0.7f))
                    }
                }

                Spacer(Modifier.height(16.dp))

                // ── Step Indicator ──
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    stepLabels.forEachIndexed { index, label ->
                        val stepNum = index + 1
                        val isActive = stepNum == currentStep
                        val isDone = stepNum < currentStep

                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(8.dp))
                                .background(
                                    when {
                                        isActive -> Color.White.copy(alpha = 0.15f)
                                        isDone -> Color.White.copy(alpha = 0.08f)
                                        else -> Color.Transparent
                                    }
                                )
                                .clickable { if (isDone) currentStep = stepNum }
                                .padding(horizontal = 8.dp, vertical = 8.dp)
                        ) {
                            Box(
                                contentAlignment = Alignment.Center,
                                modifier = Modifier
                                    .size(22.dp)
                                    .clip(CircleShape)
                                    .background(
                                        when {
                                            isDone -> Color(0xFF22C55E)
                                            isActive -> Color.White
                                            else -> Color.White.copy(alpha = 0.2f)
                                        }
                                    )
                            ) {
                                if (isDone) {
                                    Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(13.dp))
                                } else {
                                    Text(
                                        "$stepNum",
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (isActive) MaterialTheme.colorScheme.onSurface else Color.White.copy(alpha = 0.5f)
                                    )
                                }
                            }
                            Spacer(Modifier.width(6.dp))
                            Text(
                                label,
                                fontSize = 10.sp,
                                fontWeight = if (isActive) FontWeight.SemiBold else FontWeight.Normal,
                                color = if (isActive || isDone) Color.White else Color.White.copy(alpha = 0.4f),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                }
            }

            // ── Step Content ──
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                when (currentStep) {
                    // ═══ STEP 1: İsim & Tür ═══
                    1 -> {
                        // Kural Adı
                        Text("Alarm Adı", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                        OutlinedTextField(
                            value = name,
                            onValueChange = { name = it },
                            placeholder = { Text("ör. Hız İhlali Alarmı, Depo Kontrolü...", fontSize = 13.sp) },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                            shape = RoundedCornerShape(10.dp)
                        )

                        Spacer(Modifier.height(4.dp))

                        // Alarm Türü
                        Text("Alarm Türü Seçin", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)

                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            typeOptions.forEach { type ->
                                val isSelected = selectedType == type.value
                                val typeIcon = when (type.value) {
                                    "speed_violation" -> Icons.Default.Speed
                                    "idle_alarm" -> Icons.Default.HourglassBottom
                                    "movement_detection" -> Icons.Default.DirectionsCar
                                    "off_hours_usage" -> Icons.Default.Schedule
                                    "geofence_alarm" -> Icons.Default.LocationOn
                                    "ignition_on" -> Icons.Default.VpnKey
                                    "ignition_off" -> Icons.Default.PowerOff
                                    else -> Icons.Default.Notifications
                                }
                                val typeColor = when (type.value) {
                                    "speed_violation" -> Color(0xFFEF4444)
                                    "idle_alarm" -> Color(0xFFF59E0B)
                                    "movement_detection" -> Color(0xFF22C55E)
                                    "off_hours_usage" -> Color(0xFFA855F7)
                                    "geofence_alarm" -> AppColors.Indigo
                                    "ignition_on" -> Color(0xFF22C55E)
                                    "ignition_off" -> Color(0xFFEF4444)
                                    else -> AppColors.Indigo
                                }

                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(if (isSelected) typeColor.copy(alpha = 0.06f) else MaterialTheme.colorScheme.surface)
                                        .border(
                                            1.5.dp,
                                            if (isSelected) typeColor.copy(alpha = 0.3f) else MaterialTheme.colorScheme.outline,
                                            RoundedCornerShape(12.dp)
                                        )
                                        .clickable { selectedType = type.value }
                                        .padding(14.dp)
                                ) {
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier
                                            .size(40.dp)
                                            .clip(RoundedCornerShape(10.dp))
                                            .background(typeColor.copy(alpha = 0.1f))
                                    ) {
                                        Icon(typeIcon, null, tint = typeColor, modifier = Modifier.size(20.dp))
                                    }
                                    Spacer(Modifier.width(12.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(type.label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                        if (type.description.isNotEmpty()) {
                                            Text(type.description, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), maxLines = 2)
                                        }
                                    }
                                    if (isSelected) {
                                        Box(
                                            contentAlignment = Alignment.Center,
                                            modifier = Modifier.size(22.dp).clip(CircleShape).background(typeColor)
                                        ) {
                                            Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(14.dp))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══ STEP 2: Araçlar ═══
                    2 -> {
                        Text("Hangi araçlar için geçerli olsun?", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)

                        // Search
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(MaterialTheme.colorScheme.surface)
                                .border(1.dp, MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                                .padding(horizontal = 12.dp, vertical = 4.dp)
                        ) {
                            Icon(Icons.Default.Search, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(8.dp))
                            BasicTextField(
                                value = vehicleSearch,
                                onValueChange = { vehicleSearch = it },
                                singleLine = true,
                                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface),
                                decorationBox = { innerTextField ->
                                    Box(modifier = Modifier.weight(1f).padding(vertical = 8.dp)) {
                                        if (vehicleSearch.isEmpty()) Text("Plaka veya araç ara...", fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                        innerTextField()
                                    }
                                },
                                modifier = Modifier.weight(1f)
                            )
                        }

                        // Select All / Deselect All
                        val allVehicleIds = catalog?.vehicles?.map { it.assignmentId }?.toSet() ?: emptySet()
                        val allSelected = allVehicleIds.isNotEmpty() && selectedVehicles.containsAll(allVehicleIds)
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            TextButton(onClick = { selectedVehicles = allVehicleIds }) {
                                Icon(Icons.Default.SelectAll, null, modifier = Modifier.size(14.dp), tint = AppColors.Indigo)
                                Spacer(Modifier.width(4.dp))
                                Text("Tümünü Seç", fontSize = 11.sp, color = AppColors.Indigo, fontWeight = FontWeight.SemiBold)
                            }
                            if (selectedVehicles.isNotEmpty()) {
                                TextButton(onClick = { selectedVehicles = emptySet() }) {
                                    Text("Temizle (${selectedVehicles.size})", fontSize = 11.sp, color = Color.Red, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }

                        // Vehicle list
                        val filteredVehicles = if (vehicleSearch.isBlank()) catalog?.vehicles ?: emptyList()
                        else catalog?.vehicles?.filter {
                            it.plate.contains(vehicleSearch, true) || it.label.contains(vehicleSearch, true)
                        } ?: emptyList()

                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            filteredVehicles.forEach { v ->
                                val isSelected = selectedVehicles.contains(v.assignmentId)
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(if (isSelected) AppColors.Indigo.copy(alpha = 0.06f) else MaterialTheme.colorScheme.surface)
                                        .border(1.dp, if (isSelected) AppColors.Indigo.copy(alpha = 0.2f) else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                                        .clickable {
                                            selectedVehicles = if (isSelected) selectedVehicles - v.assignmentId else selectedVehicles + v.assignmentId
                                        }
                                        .padding(12.dp)
                                ) {
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier
                                            .size(20.dp)
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(if (isSelected) AppColors.Indigo else Color.Transparent)
                                            .border(1.5.dp, if (isSelected) AppColors.Indigo else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), RoundedCornerShape(4.dp))
                                    ) {
                                        if (isSelected) Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(14.dp))
                                    }
                                    Spacer(Modifier.width(10.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(v.label, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                                        if (v.plate.isNotEmpty() && v.plate != v.label) {
                                            Text(v.plate, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                        }
                                    }
                                    if (isSelected) {
                                        Icon(Icons.Default.CheckCircle, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
                                    }
                                }
                            }
                        }

                        if (catalog?.vehicles == null) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(20.dp),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = AppColors.Indigo)
                                Spacer(Modifier.width(8.dp))
                                Text("Araçlar yükleniyor...", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                            }
                        }
                    }

                    // ═══ STEP 3: Koşullar ═══
                    3 -> {
                        val typeLabel = typeOptions.firstOrNull { it.value == selectedType }?.label ?: selectedType
                        Text("$typeLabel Koşulları", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)

                        when (selectedType) {
                            "speed_violation" -> {
                                Text("Araçlarınızın aşmaması gereken hız limitini belirleyin.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                Spacer(Modifier.height(4.dp))
                                OutlinedTextField(
                                    value = speedLimit,
                                    onValueChange = { speedLimit = it.filter { c -> c.isDigit() } },
                                    label = { Text("Hız Limiti (km/s)") },
                                    leadingIcon = { Icon(Icons.Default.Speed, null, tint = Color(0xFFEF4444), modifier = Modifier.size(20.dp)) },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true,
                                    shape = RoundedCornerShape(10.dp)
                                )
                                // Common presets
                                Text("Hızlı Seçim", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    listOf("50", "80", "100", "120").forEach { preset ->
                                        val isSel = speedLimit == preset
                                        Box(
                                            contentAlignment = Alignment.Center,
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(8.dp))
                                                .background(if (isSel) AppColors.Indigo else MaterialTheme.colorScheme.surface)
                                                .border(1.dp, if (isSel) AppColors.Indigo else MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                                                .clickable { speedLimit = preset }
                                                .padding(horizontal = 16.dp, vertical = 8.dp)
                                        ) {
                                            Text("$preset km/s", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (isSel) Color.White else MaterialTheme.colorScheme.onSurface)
                                        }
                                    }
                                }
                            }
                            "idle_alarm" -> {
                                Text("Araçlarınızın rölantide kalabileceği maksimum süreyi belirleyin.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                Spacer(Modifier.height(4.dp))
                                OutlinedTextField(
                                    value = idleAfterSec,
                                    onValueChange = { idleAfterSec = it.filter { c -> c.isDigit() } },
                                    label = { Text("Rölanti Süresi (saniye)") },
                                    leadingIcon = { Icon(Icons.Default.HourglassBottom, null, tint = Color(0xFFF59E0B), modifier = Modifier.size(20.dp)) },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true,
                                    shape = RoundedCornerShape(10.dp)
                                )
                                Text("Hızlı Seçim", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    listOf("180" to "3 dk", "300" to "5 dk", "600" to "10 dk", "900" to "15 dk").forEach { (sec, label) ->
                                        val isSel = idleAfterSec == sec
                                        Box(
                                            contentAlignment = Alignment.Center,
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(8.dp))
                                                .background(if (isSel) AppColors.Indigo else MaterialTheme.colorScheme.surface)
                                                .border(1.dp, if (isSel) AppColors.Indigo else MaterialTheme.colorScheme.outline, RoundedCornerShape(8.dp))
                                                .clickable { idleAfterSec = sec }
                                                .padding(horizontal = 14.dp, vertical = 8.dp)
                                        ) {
                                            Text(label, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (isSel) Color.White else MaterialTheme.colorScheme.onSurface)
                                        }
                                    }
                                }
                            }
                            "geofence_alarm" -> {
                                Text("Alarm tetiklenecek bölgeyi seçin.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                Spacer(Modifier.height(4.dp))
                                catalog?.geofences?.forEach { gf ->
                                    val isSel = selectedGeofence == gf.id
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clip(RoundedCornerShape(10.dp))
                                            .background(if (isSel) AppColors.Indigo.copy(alpha = 0.06f) else MaterialTheme.colorScheme.surface)
                                            .border(1.dp, if (isSel) AppColors.Indigo.copy(alpha = 0.2f) else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                                            .clickable { selectedGeofence = gf.id }
                                            .padding(12.dp)
                                    ) {
                                        Icon(Icons.Default.LocationOn, null, tint = if (isSel) AppColors.Indigo else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(18.dp))
                                        Spacer(Modifier.width(10.dp))
                                        Text(gf.name, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f))
                                        if (isSel) Icon(Icons.Default.CheckCircle, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
                                    }
                                } ?: Text("Bölge bulunamadı", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                            }
                            "movement_detection" -> {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(Color(0xFF22C55E).copy(alpha = 0.06f))
                                        .padding(16.dp)
                                ) {
                                    Icon(Icons.Default.DirectionsCar, null, tint = Color(0xFF22C55E), modifier = Modifier.size(28.dp))
                                    Spacer(Modifier.height(8.dp))
                                    Text("Hareket Algılama", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                    Spacer(Modifier.height(4.dp))
                                    Text("Park halindeki araç sallanma, çekilme veya hareket etme durumunda otomatik uyarı alacaksınız. Ek koşul gerekmez.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), lineHeight = 18.sp)
                                }
                            }
                            "ignition_on" -> {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(Color(0xFF22C55E).copy(alpha = 0.06f))
                                        .padding(16.dp)
                                ) {
                                    Icon(Icons.Default.VpnKey, null, tint = Color(0xFF22C55E), modifier = Modifier.size(28.dp))
                                    Spacer(Modifier.height(8.dp))
                                    Text("Kontak Açılma", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                    Spacer(Modifier.height(4.dp))
                                    Text("Araç kontağı açıldığı anda otomatik bildirim alırsınız. Bu alarm tipi için ek koşul tanımlamanıza gerek yoktur.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), lineHeight = 18.sp)
                                }
                            }
                            "ignition_off" -> {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(Color(0xFFEF4444).copy(alpha = 0.06f))
                                        .padding(16.dp)
                                ) {
                                    Icon(Icons.Default.PowerOff, null, tint = Color(0xFFEF4444), modifier = Modifier.size(28.dp))
                                    Spacer(Modifier.height(8.dp))
                                    Text("Kontak Kapanma", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                    Spacer(Modifier.height(4.dp))
                                    Text("Araç kontağı kapandığı anda otomatik bildirim alırsınız. Bu alarm tipi için ek koşul tanımlamanıza gerek yoktur.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), lineHeight = 18.sp)
                                }
                            }
                            "off_hours_usage" -> {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(Color(0xFFA855F7).copy(alpha = 0.06f))
                                        .padding(16.dp)
                                ) {
                                    Icon(Icons.Default.Schedule, null, tint = Color(0xFFA855F7), modifier = Modifier.size(28.dp))
                                    Spacer(Modifier.height(8.dp))
                                    Text("Mesai Dışı Kullanım", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                    Spacer(Modifier.height(4.dp))
                                    Text("Varsayılan ayarlar: Hafta içi 08:00 - 18:00 arası mesai. Bu saat aralığı dışında araç kullanıldığında bildirim alırsınız.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), lineHeight = 18.sp)
                                    Spacer(Modifier.height(8.dp))
                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        listOf("Pzt", "Sal", "Çar", "Per", "Cum").forEach { day ->
                                            Box(
                                                contentAlignment = Alignment.Center,
                                                modifier = Modifier
                                                    .size(36.dp)
                                                    .clip(CircleShape)
                                                    .background(Color(0xFFA855F7).copy(alpha = 0.15f))
                                            ) {
                                                Text(day, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFFA855F7))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══ STEP 4: Bildirim ═══
                    4 -> {
                        // Channels
                        Text("Bildirim Kanalları", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                        Text("Alarm tetiklendiğinde hangi kanallardan bildirim almak istiyorsunuz?", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))

                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            data class ChannelOption(val key: String, val label: String, val desc: String, val icon: ImageVector, val color: Color)
                            val channelOptions = listOf(
                                ChannelOption("push", "Mobil Bildirim", "Telefonunuza anlık bildirim", Icons.Default.PhoneAndroid, AppColors.Indigo),
                                ChannelOption("email", "E-posta", "Detaylı alarm raporu e-posta ile", Icons.Default.Email, Color(0xFF3B82F6)),
                                ChannelOption("sms", "SMS", "Kısa mesaj ile uyarı", Icons.Default.Sms, Color(0xFF22C55E))
                            )
                            channelOptions.forEach { ch ->
                                val isSel = selectedChannels.contains(ch.key)
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(if (isSel) ch.color.copy(alpha = 0.06f) else MaterialTheme.colorScheme.surface)
                                        .border(1.5.dp, if (isSel) ch.color.copy(alpha = 0.3f) else MaterialTheme.colorScheme.outline, RoundedCornerShape(12.dp))
                                        .clickable {
                                            selectedChannels = if (isSel) selectedChannels - ch.key else selectedChannels + ch.key
                                        }
                                        .padding(14.dp)
                                ) {
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier.size(38.dp).clip(RoundedCornerShape(10.dp)).background(ch.color.copy(alpha = 0.1f))
                                    ) {
                                        Icon(ch.icon, null, tint = ch.color, modifier = Modifier.size(18.dp))
                                    }
                                    Spacer(Modifier.width(12.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(ch.label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                                        Text(ch.desc, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                    }
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier
                                            .size(22.dp)
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(if (isSel) ch.color else Color.Transparent)
                                            .border(1.5.dp, if (isSel) ch.color else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), RoundedCornerShape(4.dp))
                                    ) {
                                        if (isSel) Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(14.dp))
                                    }
                                }
                            }
                        }

                        Spacer(Modifier.height(8.dp))

                        // Recipients
                        Text("Alıcılar", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                        Text("Alarm bildirimlerini kimler alsın?", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))

                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            catalog?.recipients?.forEach { r ->
                                val isSel = selectedRecipients.contains(r.id)
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(if (isSel) AppColors.Indigo.copy(alpha = 0.06f) else MaterialTheme.colorScheme.surface)
                                        .border(1.dp, if (isSel) AppColors.Indigo.copy(alpha = 0.2f) else MaterialTheme.colorScheme.outline, RoundedCornerShape(10.dp))
                                        .clickable {
                                            selectedRecipients = if (isSel) selectedRecipients - r.id else selectedRecipients + r.id
                                        }
                                        .padding(12.dp)
                                ) {
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier.size(36.dp).clip(CircleShape).background(AppColors.Indigo.copy(alpha = 0.1f))
                                    ) {
                                        Text(
                                            r.name.take(2).uppercase(),
                                            fontSize = 12.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = AppColors.Indigo
                                        )
                                    }
                                    Spacer(Modifier.width(10.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(r.name, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                                        Text(r.email, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                                    }
                                    Box(
                                        contentAlignment = Alignment.Center,
                                        modifier = Modifier
                                            .size(20.dp)
                                            .clip(RoundedCornerShape(4.dp))
                                            .background(if (isSel) AppColors.Indigo else Color.Transparent)
                                            .border(1.5.dp, if (isSel) AppColors.Indigo else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), RoundedCornerShape(4.dp))
                                    ) {
                                        if (isSel) Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(14.dp))
                                    }
                                }
                            } ?: Row(
                                modifier = Modifier.fillMaxWidth().padding(16.dp),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = AppColors.Indigo)
                                Spacer(Modifier.width(8.dp))
                                Text("Alıcılar yükleniyor...", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
                            }
                        }

                        // Summary card
                        Spacer(Modifier.height(8.dp))
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.04f))
                                .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
                                .padding(14.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Text("Özet", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Icon(Icons.Default.Sell, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
                                Text("Tür: ${typeOptions.firstOrNull { it.value == selectedType }?.label ?: selectedType}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Icon(Icons.Default.DirectionsCar, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
                                Text("${selectedVehicles.size} araç seçildi", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                Icon(Icons.Default.Notifications, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(14.dp))
                                Text("${selectedChannels.size} kanal, ${selectedRecipients.size} alıcı", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
                            }
                        }
                    }
                }
            }

            // ── Error Message ──
            errorMsg?.let {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Error, null, tint = Color.Red, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(it, fontSize = 12.sp, color = Color.Red, modifier = Modifier.weight(1f))
                }
            }

            // ── Bottom Navigation Buttons ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Back button
                if (currentStep > 1) {
                    OutlinedButton(
                        onClick = { currentStep--; errorMsg = null },
                        modifier = Modifier.weight(1f).height(48.dp),
                        shape = RoundedCornerShape(12.dp),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
                    ) {
                        Icon(Icons.Default.ArrowBack, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurface)
                        Spacer(Modifier.width(6.dp))
                        Text("Geri", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
                    }
                }

                // Next / Save button
                Button(
                    onClick = {
                        errorMsg = null
                        when (currentStep) {
                            1 -> {
                                if (name.isBlank()) { errorMsg = "Alarm adı gerekli"; return@Button }
                                currentStep = 2
                            }
                            2 -> {
                                if (selectedVehicles.isEmpty()) { errorMsg = "En az bir araç seçin"; return@Button }
                                currentStep = 3
                            }
                            3 -> currentStep = 4
                            4 -> scope.launch { save() }
                        }
                    },
                    enabled = !isSaving,
                    modifier = Modifier.weight(if (currentStep > 1) 1.5f else 1f).height(48.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = if (currentStep == 4) Color(0xFF22C55E) else MaterialTheme.colorScheme.onSurface),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    if (isSaving) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp, color = Color.White)
                    } else {
                        Text(
                            if (currentStep == 4) "Alarm Oluştur" else "Devam Et",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp
                        )
                        Spacer(Modifier.width(6.dp))
                        Icon(
                            if (currentStep == 4) Icons.Default.Check else Icons.Default.ArrowForward,
                            null,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Detail Row
@Composable
private fun DetailRow(icon: ImageVector, title: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(icon, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(18.dp))
        Column {
            Text(title, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
            Spacer(Modifier.height(2.dp))
            Text(value, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
        }
    }
}

// MARK: - Open Maps Directions
private fun openMapsDirectionsAlarm(context: Context, lat: Double, lng: Double, label: String) {
    try {
        val gmmIntentUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
        val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri).apply { setPackage("com.google.android.apps.maps") }
        context.startActivity(mapIntent)
    } catch (_: Exception) {
        try {
            val genericUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($label)")
            context.startActivity(Intent(Intent.ACTION_VIEW, genericUri))
        } catch (_: Exception) { /* no maps app */ }
    }
}
