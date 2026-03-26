package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.components.AvatarCircle
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import org.json.JSONObject

// MARK: - AlarmEvent Model
data class AlarmEvent(
    val id: Int,
    val imei: String,
    val plate: String,
    val vehicleName: String,
    val type: String,
    val code: String,
    val lat: Double,
    val lng: Double,
    val speed: Int,
    val createdAt: String
) {
    val icon: ImageVector get() = when {
        type.contains("overspeed", true) || type.contains("hız", true) -> Icons.Default.Speed
        type.contains("brake", true) || type.contains("fren", true) -> Icons.Default.Warning
        type.contains("idle", true) || type.contains("rölanti", true) -> Icons.Default.HourglassBottom
        type.contains("geofence", true) || type.contains("bölge", true) -> Icons.Default.LocationOn
        type.contains("disconnect", true) || type.contains("bağlantı", true) -> Icons.Default.WifiOff
        type.contains("sos", true) || type.contains("panik", true) -> Icons.Default.Emergency
        type.contains("tow", true) || type.contains("çekici", true) -> Icons.Default.CarCrash
        type.contains("power", true) || type.contains("güç", true) -> Icons.Default.PowerOff
        type.contains("battery", true) || type.contains("batarya", true) -> Icons.Default.BatteryAlert
        else -> Icons.Default.Notifications
    }

    val color: Color get() = when {
        type.contains("overspeed", true) || type.contains("sos", true) -> Color(0xFFEF4444)
        type.contains("brake", true) || type.contains("disconnect", true) -> Color(0xFFF97316)
        type.contains("idle", true) || type.contains("rölanti", true) -> Color(0xFFF59E0B)
        type.contains("geofence", true) || type.contains("enter", true) -> Color(0xFF22C55E)
        else -> AppColors.Indigo
    }

    val typeLabel: String get() = when (type.lowercase()) {
        "overspeed" -> "Hız Aşımı"
        "harsh_brake" -> "Sert Fren"
        "harsh_acceleration" -> "Sert Hızlanma"
        "idle" -> "Rölanti"
        "geofence_enter" -> "Bölgeye Giriş"
        "geofence_exit" -> "Bölgeden Çıkış"
        "disconnect" -> "Bağlantı Koptu"
        "sos" -> "SOS / Panik"
        "tow" -> "Çekici Algılandı"
        "power_cut" -> "Güç Kesildi"
        "low_battery" -> "Düşük Batarya"
        "tampering" -> "Cihaz Müdahalesi"
        else -> type.replace("_", " ").replaceFirstChar { it.uppercase() }
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

    companion object {
        fun from(json: JSONObject): AlarmEvent = AlarmEvent(
            id = json.optInt("id", 0),
            imei = json.optString("imei", ""),
            plate = json.optString("plate", ""),
            vehicleName = json.optString("vehicle_name", ""),
            type = json.optString("type", ""),
            code = json.optString("code", ""),
            lat = json.optDouble("lat", 0.0),
            lng = json.optDouble("lng", 0.0),
            speed = json.optInt("speed", 0),
            createdAt = json.optString("created_at", "")
        )
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
                    newAlarms.add(AlarmEvent.from(dataArr.getJSONObject(i)))
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
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            // Tab Selector
            TabSelector(selectedTab = selectedTab, onTabSelected = { selectedTab = it })

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
                                "$totalCount alarm",
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = AppColors.TextMuted
                            )
                            Spacer(Modifier.weight(1f))
                            if (isLoading) {
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
                            items(alarms, key = { it.id }) { alarm ->
                                AlarmCard(alarm)
                            }

                            // Pagination
                            if (currentPage < lastPage) {
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
                AlarmRulesTab()
            }
        }
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
private fun AlarmRulesTab() {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Header
        item {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "${DUMMY_ALARM_RULES.size} kural tanımlı",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = AppColors.TextMuted
                )
                Spacer(Modifier.weight(1f))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.clickable { }
                ) {
                    Icon(Icons.Default.AddCircle, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
                    Text("Yeni Kural", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Indigo)
                }
            }
        }

        items(DUMMY_ALARM_RULES, key = { it.id }) { rule ->
            AlarmRuleCard(rule)
        }
    }
}

// MARK: - Alarm Rule Card
@Composable
private fun AlarmRuleCard(rule: AlarmRule) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
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
private fun AlarmCard(alarm: AlarmEvent) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
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

            if (alarm.code.isNotEmpty()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    alarm.code,
                    fontSize = 10.sp,
                    color = AppColors.TextMuted,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
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

// MARK: - Dummy Alarm Data
private val DUMMY_ALARMS = listOf(
    AlarmEvent(1, "353742378104285", "06 ATS 001", "Beyaz Sprinter", "overspeed", "Hız limiti: 120 km/s, Anlık: 138 km/s", 39.9208, 32.8541, 138, "2026-03-26 14:22:00"),
    AlarmEvent(2, "353742379713316", "34 ARV 34", "Siyah Vito", "harsh_brake", "Ani fren algılandı", 41.0082, 28.9784, 67, "2026-03-26 13:45:00"),
    AlarmEvent(3, "353742378104285", "06 ATS 001", "Beyaz Sprinter", "geofence_exit", "Ankara Merkez bölgesinden çıkış", 39.9334, 32.8597, 45, "2026-03-26 12:30:00"),
    AlarmEvent(4, "353742379713316", "34 ARV 34", "Siyah Vito", "idle", "15 dk rölanti - Kontak açık, araç durağan", 41.0136, 28.9550, 0, "2026-03-26 11:15:00"),
    AlarmEvent(5, "353742378104285", "06 ATS 001", "Beyaz Sprinter", "sos", "Panik butonu basıldı", 39.9248, 32.8662, 0, "2026-03-26 10:50:00"),
    AlarmEvent(6, "353742379713316", "34 ARV 34", "Siyah Vito", "harsh_acceleration", "Ani hızlanma algılandı", 41.0210, 28.9390, 82, "2026-03-26 10:05:00"),
    AlarmEvent(7, "353742378104285", "06 ATS 001", "Beyaz Sprinter", "disconnect", "Cihaz bağlantısı kesildi", 39.9180, 32.8450, 0, "2026-03-26 09:30:00"),
    AlarmEvent(8, "353742379713316", "34 ARV 34", "Siyah Vito", "overspeed", "Hız limiti: 50 km/s, Anlık: 73 km/s", 41.0350, 28.9850, 73, "2026-03-26 08:45:00"),
    AlarmEvent(9, "353742378104285", "06 ATS 001", "Beyaz Sprinter", "geofence_enter", "Ankara Merkez bölgesine giriş", 39.9255, 32.8540, 35, "2026-03-26 08:00:00"),
    AlarmEvent(10, "353742379713316", "34 ARV 34", "Siyah Vito", "power_cut", "Harici güç kaynağı kesildi", 41.0082, 28.9784, 0, "2026-03-25 23:10:00"),
)