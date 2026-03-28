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
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.components.AvatarCircle
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker

// MARK: - AlarmEvent Model
data class AlarmEvent(
    val id: String,
    val imei: String,
    val plate: String,
    val vehicleName: String,
    val type: String,
    val code: String,
    val description: String,
    val lat: Double,
    val lng: Double,
    val speed: Int,
    val createdAt: String,
    val isActive: Boolean = true
) {
    val statusLabel: String get() = if (isActive) "Aktif" else "Kapandı"
    val statusColor: Color get() = if (isActive) Color(0xFFEF4444) else Color(0xFF22C55E)
    // Use code + type + description to determine icon/color/label (type can be device brand like "teltonika")
    val alarmKey: String get() = "${code.lowercase()} ${type.lowercase()} ${description.lowercase()}"

    val icon: ImageVector get() = when {
        alarmKey.contains("overspeed") || alarmKey.contains("hız") -> Icons.Default.Speed
        alarmKey.contains("brake") || alarmKey.contains("fren") -> Icons.Default.Warning
        alarmKey.contains("idle") || alarmKey.contains("rölanti") -> Icons.Default.HourglassBottom
        alarmKey.contains("geofence") || alarmKey.contains("gf_") || alarmKey.contains("bölge") -> Icons.Default.LocationOn
        alarmKey.contains("disconnect") || alarmKey.contains("bağlantı") -> Icons.Default.WifiOff
        alarmKey.contains("sos") || alarmKey.contains("panik") -> Icons.Default.Emergency
        alarmKey.contains("tow") || alarmKey.contains("çek") || alarmKey.contains("taşı") -> Icons.Default.CarCrash
        alarmKey.contains("power") || alarmKey.contains("güç") -> Icons.Default.PowerOff
        alarmKey.contains("battery") || alarmKey.contains("batarya") -> Icons.Default.BatteryAlert
        alarmKey.contains("movement") || alarmKey.contains("hareket") -> Icons.Default.DirectionsCar
        else -> Icons.Default.Notifications
    }

    val color: Color get() = when {
        alarmKey.contains("overspeed") || alarmKey.contains("sos") -> Color(0xFFEF4444)
        alarmKey.contains("tow") || alarmKey.contains("çek") || alarmKey.contains("taşı") -> Color(0xFFEF4444)
        alarmKey.contains("brake") || alarmKey.contains("disconnect") -> Color(0xFFF97316)
        alarmKey.contains("idle") || alarmKey.contains("rölanti") -> Color(0xFFF59E0B)
        alarmKey.contains("geofence") || alarmKey.contains("gf_") -> Color(0xFF22C55E)
        alarmKey.contains("movement") || alarmKey.contains("hareket") -> AppColors.Indigo
        else -> AppColors.Indigo
    }

    val typeLabel: String get() {
        // If we have a Turkish description from API, use it directly
        if (description.isNotEmpty() && !description.equals(code, true)) return description
        // Map known codes to Turkish labels
        return when (code.lowercase()) {
            "t_movement" -> "Hareket Algılandı"
            "t_towing" -> "Çekme/Taşıma Alarmı"
            "t_idle" -> "Rölanti"
            "t_overspeed" -> "Hız Aşımı"
            "t_harsh_brake", "t_brake" -> "Sert Fren"
            "t_harsh_acceleration" -> "Sert Hızlanma"
            "t_power_cut" -> "Güç Kesilmesi"
            "t_sos" -> "SOS / Panik"
            "t_jamming" -> "Sinyal Karıştırma"
            "gf_enter", "geofence_enter" -> "Bölgeye Giriş"
            "gf_exit", "geofence_exit" -> "Bölgeden Çıkış"
            "overspeed" -> "Hız Aşımı"
            "harsh_brake" -> "Sert Fren"
            "harsh_acceleration" -> "Sert Hızlanma"
            "idle" -> "Rölanti"
            "disconnect" -> "Bağlantı Koptu"
            "sos" -> "SOS / Panik"
            "tow" -> "Çekici Algılandı"
            "power_cut" -> "Güç Kesildi"
            "low_battery" -> "Düşük Batarya"
            "tampering" -> "Cihaz Müdahalesi"
            else -> description.ifEmpty { code.replace("_", " ").replaceFirstChar { it.uppercase() } }
        }
    }

    val formattedDate: String get() {
        if (createdAt.length < 16) return createdAt
        return try {
            val parts = createdAt.split(" ")
            val dateParts = parts[0].split("-")
            val months = arrayOf("", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara")
            val month = dateParts[1].toIntOrNull() ?: 0
            val day = dateParts[2]
            val time = parts[1].take(5)
            "$day ${months[month.coerceIn(0, 12)]} $time"
        } catch (_: Exception) { createdAt }
    }

    val formattedFullDate: String get() {
        if (createdAt.length < 16) return createdAt
        return try {
            val parts = createdAt.split(" ")
            val dateParts = parts[0].split("-")
            val monthsFull = arrayOf("", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık")
            val year = dateParts[0]
            val month = dateParts[1].toIntOrNull() ?: 0
            val day = dateParts[2]
            val time = parts[1].take(5)
            "$day ${monthsFull[month.coerceIn(0, 12)]} $year, $time"
        } catch (_: Exception) { createdAt }
    }

    companion object {
        fun from(json: JSONObject, index: Int = 0): AlarmEvent = try {
            AlarmEvent(
                id = json.optString("id", "alarm_$index"),
                imei = json.optString("imei", ""),
                plate = json.optString("plate", ""),
                vehicleName = json.optString("vehicle_name", ""),
                type = json.optString("type", ""),
                code = json.optString("code", ""),
                description = json.optString("description", ""),
                lat = json.optString("lat", "0").toDoubleOrNull() ?: 0.0,
                lng = json.optString("lng", "0").toDoubleOrNull() ?: 0.0,
                speed = json.optInt("speed", 0),
                createdAt = json.optString("created_at", ""),
                isActive = json.optBoolean("is_active", true)
            )
        } catch (e: Exception) {
            AlarmEvent("fallback_$index", "", "", "", "unknown", "", "", 0.0, 0.0, 0, "")
        }
    }
}

// MARK: - Alarm Rule Model
data class AlarmRule(
    val id: Int,
    val name: String,
    val type: String,
    val condition: String,
    val vehicles: String,
    val isActive: Boolean,
    val createdAt: String
) {
    val icon: ImageVector get() = when (type.lowercase()) {
        "overspeed" -> Icons.Default.Speed
        "geofence" -> Icons.Default.LocationOn
        "idle" -> Icons.Default.HourglassBottom
        "harsh_brake" -> Icons.Default.Warning
        "disconnect" -> Icons.Default.WifiOff
        "power_cut" -> Icons.Default.PowerOff
        "sos" -> Icons.Default.Emergency
        else -> Icons.Default.Notifications
    }

    val color: Color get() = when (type.lowercase()) {
        "overspeed", "sos" -> Color(0xFFEF4444)
        "geofence" -> Color(0xFF22C55E)
        "idle" -> Color(0xFFF59E0B)
        "harsh_brake", "disconnect" -> Color(0xFFF97316)
        else -> AppColors.Indigo
    }

    val typeLabel: String get() = when (type.lowercase()) {
        "overspeed" -> "Hız Aşımı"
        "geofence" -> "Geofence"
        "idle" -> "Rölanti"
        "harsh_brake" -> "Sert Fren"
        "disconnect" -> "Bağlantı Kopma"
        "power_cut" -> "Güç Kesilmesi"
        "sos" -> "SOS / Panik"
        else -> type.replace("_", " ").replaceFirstChar { it.uppercase() }
    }
}

// MARK: - Dummy Alarm Rules
private val DUMMY_ALARM_RULES = listOf(
    AlarmRule(1, "Şehir İçi Hız Limiti", "overspeed", "Hız > 50 km/s", "Tüm Araçlar", true, "2026-01-15"),
    AlarmRule(2, "Otoban Hız Limiti", "overspeed", "Hız > 120 km/s", "Tüm Araçlar", true, "2026-01-15"),
    AlarmRule(3, "Ankara Merkez Bölgesi", "geofence", "Bölgeden çıkışta bildir", "06 ATS 001, 06 TUV 222", true, "2026-02-10"),
    AlarmRule(4, "İstanbul Depo Bölgesi", "geofence", "Bölgeye girişte bildir", "34 ARV 34, 34 ABC 123", false, "2026-02-20"),
    AlarmRule(5, "Rölanti Uyarısı", "idle", "10 dk üzeri rölanti", "Tüm Araçlar", true, "2026-03-01"),
    AlarmRule(6, "Sert Fren Algılama", "harsh_brake", "Ani fren algılandığında", "Tüm Araçlar", true, "2026-03-05"),
    AlarmRule(7, "Bağlantı Kopma Uyarısı", "disconnect", "Cihaz bağlantısı kesildiğinde", "06 ATS 001", false, "2026-03-10"),
    AlarmRule(8, "SOS Butonu", "sos", "Panik butonu basıldığında", "Tüm Araçlar", true, "2026-03-12"),
)

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
fun AlarmsScreen(onMenuClick: () -> Unit) {
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // Tab state
    var selectedTab by remember { mutableIntStateOf(0) }

    // Search
    var searchText by remember { mutableStateOf("") }

    // Detail sheets
    var selectedAlarm by remember { mutableStateOf<AlarmEvent?>(null) }
    var selectedRule by remember { mutableStateOf<AlarmRule?>(null) }

    // State
    var alarms by remember { mutableStateOf(listOf<AlarmEvent>()) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var currentPage by remember { mutableIntStateOf(1) }
    var lastPage by remember { mutableIntStateOf(1) }
    var totalCount by remember { mutableIntStateOf(0) }

    // Filtreler
    var selectedType by remember { mutableStateOf<String?>(null) }
    var showFilterSheet by remember { mutableStateOf(false) }

    val hasActiveFilters = selectedType != null

    // Dummy veriler
    val dummyAlarms = DUMMY_ALARMS

    // API çağrısı
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
            // API henüz hazır değilse dummy veri göster
            if (!append) {
                alarms = dummyAlarms
                totalCount = alarms.size
                currentPage = 1
                lastPage = 1
            }
            errorMessage = null
        }

        isLoading = false
    }

    // İlk yükleme
    LaunchedEffect(Unit) {
        fetchAlarms()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("Alarmlar", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("İzleme / Alarmlar", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, null, tint = AppColors.Navy)
                    }
                },
                actions = {
                    // Filtre butonu - sadece Gelen Alarmlar tabında göster
                    if (selectedTab == 0) {
                        IconButton(onClick = { showFilterSheet = true }) {
                            Icon(
                                if (hasActiveFilters) Icons.Default.FilterAlt else Icons.Default.FilterList,
                                "Filtreler",
                                tint = if (hasActiveFilters) AppColors.Indigo else AppColors.TextMuted
                            )
                        }
                    }
                    AvatarCircle(initials = user?.avatar ?: "A", size = 30.dp)
                    Spacer(Modifier.width(8.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        },
        containerColor = AppColors.Bg
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

        val filteredRules = if (searchText.isBlank()) DUMMY_ALARM_RULES else {
            val q = searchText.lowercase()
            DUMMY_ALARM_RULES.filter {
                it.name.lowercase().contains(q) ||
                it.typeLabel.lowercase().contains(q) ||
                it.condition.lowercase().contains(q) ||
                it.vehicles.lowercase().contains(q)
            }
        }

        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
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
                // MARK: Gelen Alarmlar Tab
                // Aktif filtre bar
                if (hasActiveFilters) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(AppColors.Surface)
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

                // İçerik
                when {
                    isLoading && alarms.isEmpty() -> LoadingContent()
                    errorMessage != null && alarms.isEmpty() -> ErrorContent(errorMessage!!) {
                        scope.launch { fetchAlarms() }
                    }
                    alarms.isEmpty() -> EmptyContent(hasActiveFilters) {
                        selectedType = null
                        scope.launch { fetchAlarms() }
                    }
                    else -> {
                        // Sonuç sayısı
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                "${filteredAlarms.size} alarm",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = AppColors.TextMuted
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

                            // Pagination — only when NOT searching
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
                                        Text("Yükleniyor...", fontSize = 12.sp, color = AppColors.TextMuted)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // MARK: Alarm Kuralları Tab
                AlarmRulesTab(filteredRules = filteredRules, onRuleClick = { selectedRule = it })
            }
        }
    }

    // Alarm Detail Bottom Sheet
    selectedAlarm?.let { alarm ->
        AlarmDetailSheet(alarm = alarm, onDismiss = { selectedAlarm = null })
    }

    // Rule Detail Bottom Sheet
    selectedRule?.let { rule ->
        RuleDetailSheet(rule = rule, onDismiss = { selectedRule = null })
    }

    // Filtre Bottom Sheet
    if (showFilterSheet) {
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            containerColor = AppColors.Surface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = 32.dp)
            ) {
                Text("Alarm Türü", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
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
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Navy),
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
            .background(AppColors.Surface)
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 4.dp)
    ) {
        Icon(Icons.Default.Search, null, tint = AppColors.TextMuted, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(8.dp))
        BasicTextField(
            value = text,
            onValueChange = onTextChange,
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(
                fontSize = 13.sp,
                color = AppColors.TextPrimary
            ),
            decorationBox = { innerTextField ->
                Box(modifier = Modifier.weight(1f).padding(vertical = 6.dp)) {
                    if (text.isEmpty()) {
                        Text(placeholder, fontSize = 13.sp, color = AppColors.TextMuted)
                    }
                    innerTextField()
                }
            },
            modifier = Modifier.weight(1f)
        )
        if (text.isNotEmpty()) {
            IconButton(onClick = { onTextChange("") }, modifier = Modifier.size(24.dp)) {
                Icon(Icons.Default.Close, null, tint = AppColors.TextMuted, modifier = Modifier.size(14.dp))
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
            .background(AppColors.Surface)
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            .padding(4.dp)
    ) {
        // Tab 0: Gelen Alarmlar
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selectedTab == 0) AppColors.Navy else Color.Transparent)
                .clickable { onTabSelected(0) }
                .padding(vertical = 10.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.NotificationsActive, null, tint = if (selectedTab == 0) Color.White else AppColors.TextMuted, modifier = Modifier.size(14.dp))
                Text("Gelen Alarmlar", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (selectedTab == 0) Color.White else AppColors.TextMuted)
            }
        }

        // Tab 1: Alarm Kuralları
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selectedTab == 1) AppColors.Navy else Color.Transparent)
                .clickable { onTabSelected(1) }
                .padding(vertical = 10.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Settings, null, tint = if (selectedTab == 1) Color.White else AppColors.TextMuted, modifier = Modifier.size(14.dp))
                Text("Alarm Kuralları", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = if (selectedTab == 1) Color.White else AppColors.TextMuted)
            }
        }
    }
}

// MARK: - Alarm Rules Tab
@Composable
private fun AlarmRulesTab(filteredRules: List<AlarmRule>, onRuleClick: (AlarmRule) -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Yeni Kural Ekle — kart tarzı buton
        item {
            NewRuleButton()
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
                    color = AppColors.TextMuted
                )
            }
        }

        items(filteredRules, key = { it.id }) { rule ->
            AlarmRuleCard(rule, onClick = { onRuleClick(rule) })
        }
    }
}

// MARK: - New Rule Button (Kart tarzı)
@Composable
private fun NewRuleButton() {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Indigo.copy(alpha = 0.04f))
            .border(1.dp, AppColors.Indigo.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
            .clickable { }
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
            Text("Araçlarınız için özel alarm kuralı tanımlayın", fontSize = 10.sp, color = AppColors.TextMuted)
        }

        Icon(Icons.Default.ChevronRight, null, tint = AppColors.Indigo.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
    }
}

// MARK: - Alarm Rule Card
@Composable
private fun AlarmRuleCard(rule: AlarmRule, onClick: () -> Unit = {}) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
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
                Text(rule.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextPrimary)
                Text(rule.typeLabel, fontSize = 11.sp, color = AppColors.TextMuted)
            }

            // Aktif/Pasif badge
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (rule.isActive) Color(0xFF22C55E).copy(alpha = 0.1f) else Color.Gray.copy(alpha = 0.1f))
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(if (rule.isActive) Color(0xFF22C55E) else Color.Gray)
                )
                Text(
                    if (rule.isActive) "Aktif" else "Pasif",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (rule.isActive) Color(0xFF22C55E) else Color.Gray
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
                Icon(Icons.Default.Warning, null, tint = AppColors.TextFaint, modifier = Modifier.size(12.dp))
                Text("Koşul: ${rule.condition}", fontSize = 11.sp, color = AppColors.TextSecondary)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.DirectionsCar, null, tint = AppColors.TextFaint, modifier = Modifier.size(12.dp))
                Text("Araçlar: ${rule.vehicles}", fontSize = 11.sp, color = AppColors.TextSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
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
            .background(AppColors.Surface)
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
                    color = AppColors.TextPrimary,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    alarm.formattedDate,
                    fontSize = 10.sp,
                    color = AppColors.TextFaint
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
                        Icon(Icons.Default.Speed, null, tint = AppColors.TextMuted, modifier = Modifier.size(11.dp))
                        Text("${alarm.speed} km/s", fontSize = 10.sp, color = AppColors.TextMuted)
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
                        color = AppColors.TextMuted,
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
            tint = AppColors.TextFaint,
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
            tint = AppColors.TextMuted,
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
            color = if (isSelected) AppColors.Indigo else AppColors.TextSecondary,
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
            Text("Alarmlar yükleniyor...", fontSize = 13.sp, color = AppColors.TextMuted)
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
            Text("Bir hata oluştu", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextPrimary)
            Spacer(Modifier.height(4.dp))
            Text(message, fontSize = 12.sp, color = AppColors.TextMuted, modifier = Modifier.padding(horizontal = 40.dp))
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
            Icon(Icons.Default.NotificationsOff, null, tint = AppColors.TextFaint, modifier = Modifier.size(48.dp))
            Spacer(Modifier.height(12.dp))
            Text("Alarm Bulunamadı", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextPrimary)
            Spacer(Modifier.height(4.dp))
            Text(
                "Seçili filtrelere uygun alarm kaydı yok.\nFiltrelerinizi değiştirerek tekrar deneyebilirsiniz.",
                fontSize = 12.sp,
                color = AppColors.TextMuted,
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
        containerColor = AppColors.Bg
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
                Text(alarm.typeLabel, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.TextPrimary)
                Spacer(Modifier.height(4.dp))
                Text(alarm.formattedFullDate, fontSize = 12.sp, color = AppColors.TextMuted)
            }

            Spacer(Modifier.height(8.dp))

            // Details
            DetailRow(icon = Icons.Default.DirectionsCar, title = "Araç", value = if (alarm.plate.isNotEmpty()) "${alarm.plate} — ${alarm.vehicleName}" else alarm.vehicleName)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Tag, title = "IMEI", value = alarm.imei)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Speed, title = "Hız", value = if (alarm.speed > 0) "${alarm.speed} km/s" else "—")
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Description, title = "Açıklama", value = alarm.description.ifEmpty { alarm.code }.ifEmpty { "—" })
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Circle, title = "Durum", value = alarm.statusLabel)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.LocationOn, title = "Konum", value = String.format("%.4f, %.4f", alarm.lat, alarm.lng))
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
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
                        Text("Alarm Konumu", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextPrimary)
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
private fun RuleDetailSheet(rule: AlarmRule, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = AppColors.Bg
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
                Text(rule.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.TextPrimary)
                Spacer(Modifier.height(8.dp))
                // Aktif/Pasif badge
                Row(
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(if (rule.isActive) Color(0xFF22C55E).copy(alpha = 0.1f) else Color.Gray.copy(alpha = 0.1f))
                        .padding(horizontal = 12.dp, vertical = 5.dp)
                ) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(if (rule.isActive) Color(0xFF22C55E) else Color.Gray))
                    Text(
                        if (rule.isActive) "Aktif" else "Pasif",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (rule.isActive) Color(0xFF22C55E) else Color.Gray
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Details
            DetailRow(icon = Icons.Default.Sell, title = "Alarm Türü", value = rule.typeLabel)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.Warning, title = "Koşul", value = rule.condition)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.DirectionsCar, title = "Araçlar", value = rule.vehicles)
            HorizontalDivider(modifier = Modifier.padding(start = 52.dp), color = AppColors.BorderSoft.copy(alpha = 0.5f))
            DetailRow(icon = Icons.Default.CalendarMonth, title = "Oluşturulma", value = rule.createdAt)

            // Actions
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = {},
                    modifier = Modifier.fillMaxWidth().height(44.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.Edit, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Kuralı Düzenle", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                }

                OutlinedButton(
                    onClick = {},
                    modifier = Modifier.fillMaxWidth().height(44.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.Red),
                    border = BorderStroke(1.dp, Color.Red.copy(alpha = 0.3f)),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Icon(Icons.Default.Delete, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Kuralı Sil", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
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
        Icon(icon, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp))
        Column {
            Text(title, fontSize = 11.sp, color = AppColors.TextFaint)
            Spacer(Modifier.height(2.dp))
            Text(value, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.TextPrimary)
        }
    }
}

// MARK: - Dummy Alarm Data
private val DUMMY_ALARMS = listOf(
    AlarmEvent("d1", "353742378104285", "06 ATS 001", "Beyaz Sprinter", "overspeed", "Hız limiti: 120 km/s, Anlık: 138 km/s", "", 39.9208, 32.8541, 138, "2026-03-26 14:22:00"),
    AlarmEvent("d2", "353742379713316", "34 ARV 34", "Siyah Vito", "harsh_brake", "Ani fren algılandı", "", 41.0082, 28.9784, 67, "2026-03-26 13:45:00"),
    AlarmEvent("d3", "353742378104285", "06 ATS 001", "Beyaz Sprinter", "geofence_exit", "Ankara Merkez bölgesinden çıkış", "", 39.9334, 32.8597, 45, "2026-03-26 12:30:00"),
    AlarmEvent("d4", "353742379713316", "34 ARV 34", "Siyah Vito", "idle", "15 dk rölanti - Kontak açık, araç durağan", "", 41.0136, 28.9550, 0, "2026-03-26 11:15:00"),
    AlarmEvent("d5", "353742378104285", "06 ATS 001", "Beyaz Sprinter", "sos", "Panik butonu basıldı", "", 39.9248, 32.8662, 0, "2026-03-26 10:50:00"),
    AlarmEvent("d6", "353742379713316", "34 ARV 34", "Siyah Vito", "harsh_acceleration", "Ani hızlanma algılandı", "", 41.0210, 28.9390, 82, "2026-03-26 10:05:00"),
    AlarmEvent("d7", "353742378104285", "06 ATS 001", "Beyaz Sprinter", "disconnect", "Cihaz bağlantısı kesildi", "", 39.9180, 32.8450, 0, "2026-03-26 09:30:00"),
    AlarmEvent("d8", "353742379713316", "34 ARV 34", "Siyah Vito", "overspeed", "Hız limiti: 50 km/s, Anlık: 73 km/s", "", 41.0350, 28.9850, 73, "2026-03-26 08:45:00"),
    AlarmEvent("d9", "353742378104285", "06 ATS 001", "Beyaz Sprinter", "geofence_enter", "Ankara Merkez bölgesine giriş", "", 39.9255, 32.8540, 35, "2026-03-26 08:00:00"),
    AlarmEvent("d10", "353742379713316", "34 ARV 34", "Siyah Vito", "power_cut", "Harici güç kaynağı kesildi", "", 41.0082, 28.9784, 0, "2026-03-25 23:10:00"),
)

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