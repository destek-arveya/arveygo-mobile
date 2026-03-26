package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.models.Driver
import com.arveya.arveygo.models.DriverStats
import com.arveya.arveygo.models.DriversResponse
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.components.AvatarCircle
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DriversScreen(
    onMenuClick: () -> Unit
) {
    val authVM = LocalAuthViewModel.current
    val user by authVM.currentUser.collectAsState()
    val scope = rememberCoroutineScope()

    var drivers by remember { mutableStateOf<List<Driver>>(emptyList()) }
    var stats by remember { mutableStateOf(DriverStats()) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedDriver by remember { mutableStateOf<Driver?>(null) }
    var searchText by remember { mutableStateOf("") }
    var filterStatus by remember { mutableStateOf("all") }
    var showAddDialog by remember { mutableStateOf(false) }

    // Fetch drivers
    LaunchedEffect(Unit) {
        isLoading = true
        try {
            val response = APIService.fetchDrivers()
            drivers = response.drivers
            stats = response.stats
        } catch (e: Exception) {
            android.util.Log.e("Drivers", "Error fetching drivers", e)
        }
        isLoading = false
    }

    val filteredDrivers = remember(drivers, searchText, filterStatus) {
        var result = drivers
        if (searchText.isNotEmpty()) {
            result = result.filter {
                it.name.contains(searchText, ignoreCase = true) ||
                it.driverCode.contains(searchText, ignoreCase = true) ||
                it.vehicle.contains(searchText, ignoreCase = true) ||
                it.phone.contains(searchText, ignoreCase = true)
            }
        }
        if (filterStatus != "all") {
            result = result.filter { it.status == filterStatus }
        }
        result
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, null, tint = AppColors.Navy, modifier = Modifier.size(22.dp))
                    }
                },
                title = {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Sürücüler", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("Sürücü Yönetimi", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = {
                    IconButton(onClick = { showAddDialog = true }) {
                        Icon(Icons.Default.PersonAdd, null, tint = AppColors.Indigo)
                    }
                    AvatarCircle(initials = user?.avatar ?: "A", size = 30.dp)
                    Spacer(Modifier.width(12.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White)
            )
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(AppColors.Bg)
        ) {
            if (isLoading && drivers.isEmpty()) {
                CircularProgressIndicator(
                    color = AppColors.Indigo,
                    modifier = Modifier.size(32.dp).align(Alignment.Center)
                )
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Stats strip
                    item {
                        LazyRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            item { StatChip(Icons.Default.People, "Toplam", "${stats.total}", AppColors.Navy) }
                            item { StatChip(Icons.Default.CheckCircle, "Aktif", "${stats.active}", AppColors.Online) }
                            item { StatChip(Icons.Default.CellTower, "Takipli", "${stats.tracked}", AppColors.Indigo) }
                            item { StatChip(Icons.Default.ThumbUp, "İyi", "${stats.good}", AppColors.Online) }
                            item { StatChip(Icons.Default.Warning, "Düşük", "${stats.low}", Color.Red) }
                        }
                    }

                    // Search bar
                    item {
                        OutlinedTextField(
                            value = searchText,
                            onValueChange = { searchText = it },
                            placeholder = { Text("Sürücü ara...", fontSize = 13.sp) },
                            leadingIcon = { Icon(Icons.Default.Search, null, modifier = Modifier.size(18.dp)) },
                            trailingIcon = {
                                if (searchText.isNotEmpty()) {
                                    IconButton(onClick = { searchText = "" }) {
                                        Icon(Icons.Default.Close, null, modifier = Modifier.size(16.dp))
                                    }
                                }
                            },
                            singleLine = true,
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.fillMaxWidth(),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = AppColors.Indigo,
                                unfocusedBorderColor = AppColors.BorderSoft,
                                focusedContainerColor = AppColors.Surface,
                                unfocusedContainerColor = AppColors.Surface
                            )
                        )
                    }

                    // Status chips
                    item {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            StatusChip("all", "Tümü", null, filterStatus) { filterStatus = it }
                            StatusChip("online", "Çevrimiçi", AppColors.Online, filterStatus) { filterStatus = it }
                            StatusChip("idle", "Boşta", AppColors.Idle, filterStatus) { filterStatus = it }
                            StatusChip("offline", "Çevrimdışı", AppColors.Offline, filterStatus) { filterStatus = it }
                        }
                    }

                    if (filteredDrivers.isEmpty()) {
                        item {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.fillMaxWidth().padding(vertical = 40.dp)
                            ) {
                                Icon(Icons.Default.People, null, tint = AppColors.TextFaint, modifier = Modifier.size(32.dp))
                                Spacer(Modifier.height(8.dp))
                                Text("Sürücü bulunamadı", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted)
                            }
                        }
                    } else {
                        items(filteredDrivers, key = { it.id }) { driver ->
                            DriverCard(driver = driver, isSelected = selectedDriver?.id == driver.id) {
                                selectedDriver = driver
                            }
                        }
                    }

                    item { Spacer(Modifier.height(16.dp)) }
                }
            }
        }
    }

    // Driver Detail bottom sheet
    selectedDriver?.let { driver ->
        DriverDetailSheet(driver = driver, onDismiss = { selectedDriver = null })
    }

    // Add driver dialog
    if (showAddDialog) {
        AddDriverDialog(
            onDismiss = { showAddDialog = false },
            onSave = { data ->
                showAddDialog = false
                scope.launch {
                    try {
                        APIService.createDriver(data)
                        val response = APIService.fetchDrivers()
                        drivers = response.drivers
                        stats = response.stats
                    } catch (e: Exception) {
                        android.util.Log.e("Drivers", "Create error", e)
                    }
                }
            }
        )
    }
}

@Composable
private fun StatChip(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, value: String, color: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(AppColors.Surface, RoundedCornerShape(20.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(20.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp)
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(12.dp))
        Spacer(Modifier.width(4.dp))
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        Spacer(Modifier.width(4.dp))
        Text(label, fontSize = 10.sp, color = AppColors.TextMuted)
    }
}

@Composable
private fun StatusChip(key: String, label: String, dotColor: Color?, selected: String, onSelect: (String) -> Unit) {
    val isActive = selected == key
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(if (isActive) AppColors.Navy else Color.Transparent)
            .border(1.dp, if (isActive) AppColors.Navy else AppColors.BorderSoft, RoundedCornerShape(20.dp))
            .clickable { onSelect(key) }
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        if (dotColor != null) {
            Box(Modifier.size(6.dp).clip(CircleShape).background(if (isActive) Color.White else dotColor))
            Spacer(Modifier.width(4.dp))
        }
        Text(label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = if (isActive) Color.White else AppColors.TextMuted)
    }
}

@Composable
private fun DriverCard(driver: Driver, isSelected: Boolean, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(AppColors.Surface)
            .border(
                width = if (isSelected) 1.5.dp else 1.dp,
                color = if (isSelected) AppColors.Indigo else AppColors.BorderSoft,
                shape = RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onClick)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(14.dp)
        ) {
            // Avatar with status dot
            Box {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(44.dp).clip(CircleShape).background(driver.avatarColor.copy(alpha = 0.15f))
                ) {
                    Text(driver.initials, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = driver.avatarColor)
                }
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                        .padding(1.5.dp)
                        .clip(CircleShape)
                        .background(driver.statusColor)
                        .align(Alignment.BottomEnd)
                )
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(driver.name, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (driver.driverCode.isNotEmpty()) {
                        Spacer(Modifier.width(6.dp))
                        Text(
                            driver.driverCode, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.TextFaint,
                            modifier = Modifier.background(AppColors.Bg, RoundedCornerShape(4.dp)).padding(horizontal = 5.dp, vertical = 1.dp)
                        )
                    }
                }
                Spacer(Modifier.height(2.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.DirectionsCar, null, tint = AppColors.TextFaint, modifier = Modifier.size(10.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(driver.vehicle, fontSize = 11.sp, color = AppColors.TextMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                if (driver.phone.isNotEmpty()) {
                    Spacer(Modifier.height(1.dp))
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Phone, null, tint = AppColors.TextFaint, modifier = Modifier.size(10.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(driver.phone, fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                }
            }

            // Score circle
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Box(contentAlignment = Alignment.Center, modifier = Modifier.size(42.dp)) {
                    androidx.compose.foundation.Canvas(modifier = Modifier.size(38.dp)) {
                        drawCircle(color = driver.scoreColor.copy(alpha = 0.2f), style = Stroke(width = 3.dp.toPx()))
                        drawArc(
                            color = driver.scoreColor,
                            startAngle = -90f,
                            sweepAngle = 360f * driver.scoreGeneral / 100f,
                            useCenter = false,
                            style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
                        )
                    }
                    Text("${driver.scoreGeneral}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = driver.scoreColor)
                }
                Text("Skor", fontSize = 8.sp, color = AppColors.TextFaint)
            }
        }

        // Bottom stats row
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp).padding(bottom = 10.dp)
        ) {
            MiniStat(Icons.Default.Route, "${String.format("%.0f", driver.totalDistanceKm)} km", Modifier.weight(1f))
            MiniStat(Icons.Default.SwapHoriz, "${driver.tripCount} sefer", Modifier.weight(1f))
            MiniStat(Icons.Default.Speed, "${driver.overspeedCount} hız", Modifier.weight(1f))
            MiniStat(Icons.Default.Notifications, "${driver.alarmCount} alarm", Modifier.weight(1f))
        }
    }
}

@Composable
private fun MiniStat(icon: androidx.compose.ui.graphics.vector.ImageVector, value: String, modifier: Modifier = Modifier) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = modifier) {
        Icon(icon, null, tint = AppColors.TextFaint, modifier = Modifier.size(9.dp))
        Spacer(Modifier.width(3.dp))
        Text(value, fontSize = 9.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DriverDetailSheet(driver: Driver, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = AppColors.Surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            // Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(64.dp).clip(CircleShape).background(driver.avatarColor.copy(alpha = 0.15f))
                ) {
                    Text(driver.initials, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = driver.avatarColor)
                }
                Spacer(Modifier.height(8.dp))
                Text(driver.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(driver.statusColor))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        when (driver.status) { "online" -> "Çevrimiçi"; "idle" -> "Boşta"; else -> "Çevrimdışı" },
                        fontSize = 12.sp, color = AppColors.TextMuted
                    )
                    Text(" · ", color = AppColors.TextFaint)
                    Text(driver.role, fontSize = 12.sp, color = AppColors.TextMuted)
                }
            }

            Spacer(Modifier.height(16.dp))

            // Contact
            DetailSection("İletişim") {
                if (driver.phone.isNotEmpty()) DetailRow(Icons.Default.Phone, "Telefon", driver.phone)
                if (driver.email.isNotEmpty()) DetailRow(Icons.Default.Email, "E-posta", driver.email)
                if (driver.employeeNo.isNotEmpty()) DetailRow(Icons.Default.Numbers, "Sicil No", driver.employeeNo)
                if (driver.driverCode.isNotEmpty()) DetailRow(Icons.Default.QrCode, "Sürücü Kodu", driver.driverCode)
            }

            // Vehicle
            DetailSection("Araç Bilgisi") {
                DetailRow(Icons.Default.DirectionsCar, "Mevcut Araç", driver.vehicle)
                if (driver.model.isNotEmpty()) DetailRow(Icons.Default.DirectionsCar, "Model", driver.model)
                if (driver.city.isNotEmpty()) DetailRow(Icons.Default.LocationOn, "Şehir", driver.city)
            }

            // Scores
            DetailSection("Performans Skorları") {
                ScoreBar("Genel", driver.scoreGeneral)
                ScoreBar("Hız", driver.scoreSpeed)
                ScoreBar("Fren", driver.scoreBrake)
                ScoreBar("Yakıt", driver.scoreFuel)
                ScoreBar("Güvenlik", driver.scoreSafety)
            }

            // Stats
            DetailSection("İstatistikler") {
                DetailRow(Icons.Default.Route, "Toplam Mesafe", "${String.format("%.1f", driver.totalDistanceKm)} km")
                DetailRow(Icons.Default.SwapHoriz, "Sefer Sayısı", "${driver.tripCount}")
                DetailRow(Icons.Default.Speed, "Hız İhlali", "${driver.overspeedCount}")
                DetailRow(Icons.Default.Notifications, "Alarm", "${driver.alarmCount}")
            }

            if (driver.notes.isNotEmpty()) {
                DetailSection("Notlar") {
                    Text(driver.notes, fontSize = 12.sp, color = AppColors.TextSecondary, modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                }
            }
        }
    }
}

@Composable
private fun DetailSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier = Modifier.padding(bottom = 12.dp)) {
        Text(title, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.TextFaint, modifier = Modifier.padding(bottom = 6.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Surface, RoundedCornerShape(10.dp))
                .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(10.dp))
        ) {
            content()
        }
    }
}

@Composable
private fun DetailRow(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(10.dp))
        Text(label, fontSize = 12.sp, color = AppColors.TextMuted)
        Spacer(Modifier.weight(1f))
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun ScoreBar(label: String, score: Int) {
    val color = when {
        score >= 85 -> AppColors.Online
        score >= 70 -> AppColors.Idle
        else -> AppColors.Offline
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)
    ) {
        Text(label, fontSize = 12.sp, color = AppColors.TextMuted, modifier = Modifier.width(60.dp))
        Box(
            modifier = Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(3.dp)).background(AppColors.Bg)
        ) {
            Box(
                modifier = Modifier.fillMaxHeight().fillMaxWidth(score / 100f).clip(RoundedCornerShape(3.dp)).background(color)
            )
        }
        Spacer(Modifier.width(8.dp))
        Text("$score", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = color, modifier = Modifier.width(28.dp))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddDriverDialog(onDismiss: () -> Unit, onSave: (Map<String, Any>) -> Unit) {
    var fullName by remember { mutableStateOf("") }
    var driverCode by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var status by remember { mutableStateOf("active") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("Yeni Sürücü", fontWeight = FontWeight.Bold, color = AppColors.Navy)
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = fullName, onValueChange = { fullName = it },
                    label = { Text("Ad Soyad *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
                OutlinedTextField(
                    value = driverCode, onValueChange = { driverCode = it },
                    label = { Text("Sürücü Kodu") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
                OutlinedTextField(
                    value = phone, onValueChange = { phone = it },
                    label = { Text("Telefon") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
                OutlinedTextField(
                    value = email, onValueChange = { email = it },
                    label = { Text("E-posta") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(8.dp)
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val data = mutableMapOf<String, Any>("full_name" to fullName, "status" to status)
                    if (driverCode.isNotEmpty()) data["driver_code"] = driverCode
                    if (phone.isNotEmpty()) data["phone"] = phone
                    if (email.isNotEmpty()) data["email"] = email
                    onSave(data)
                },
                enabled = fullName.isNotEmpty()
            ) {
                Text("Kaydet", fontWeight = FontWeight.SemiBold, color = if (fullName.isNotEmpty()) AppColors.Indigo else AppColors.TextFaint)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("İptal", color = AppColors.TextMuted)
            }
        }
    )
}
