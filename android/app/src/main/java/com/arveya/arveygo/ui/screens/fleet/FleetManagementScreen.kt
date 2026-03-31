package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.animation.*
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import org.json.JSONObject

// ============================================================================
// MARK: - Tab Enum
// ============================================================================
enum class FleetTab(val label: String, val icon: ImageVector) {
    MAINTENANCE("Bakım", Icons.Default.Build),
    COSTS("Masraf", Icons.Default.Receipt),
    DOCUMENTS("Belge", Icons.Default.Description),
    TIRES("Lastik", Icons.Default.TireRepair)
}

// ============================================================================
// MARK: - FleetManagementScreen
// ============================================================================
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FleetManagementScreen() {
    var selectedTab by remember { mutableStateOf(FleetTab.MAINTENANCE) }
    var showAddSheet by remember { mutableStateOf(false) }
    var isRefreshing by remember { mutableStateOf(false) }

    // Catalog
    var catalog by remember { mutableStateOf(FleetCatalog()) }
    var reminders by remember { mutableStateOf<List<FleetReminder>>(emptyList()) }

    // Data lists
    var maintenanceList by remember { mutableStateOf<List<FleetMaintenance>>(emptyList()) }
    var costsList by remember { mutableStateOf<List<VehicleCost>>(emptyList()) }
    var documentsList by remember { mutableStateOf<List<FleetDocument>>(emptyList()) }
    var tiresList by remember { mutableStateOf<List<FleetTire>>(emptyList()) }

    // Loading & error
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Search & filter
    var searchText by remember { mutableStateOf("") }
    var selectedVehicleFilter by remember { mutableStateOf<String?>(null) } // null = all, else imei
    var showVehicleFilterDropdown by remember { mutableStateOf(false) }

    // Edit item
    var editingMaintenance by remember { mutableStateOf<FleetMaintenance?>(null) }
    var editingCost by remember { mutableStateOf<VehicleCost?>(null) }
    var editingDocument by remember { mutableStateOf<FleetDocument?>(null) }
    var editingTire by remember { mutableStateOf<FleetTire?>(null) }

    val scope = rememberCoroutineScope()
    val focusManager = LocalFocusManager.current

    // Fetch all data
    fun loadAll() {
        scope.launch {
            isRefreshing = true
            isLoading = true
            errorMessage = null
            try {
                catalog = APIService.fetchFleetCatalog()
                reminders = APIService.fetchFleetReminders()
                val (m, _) = APIService.fetchFleetMaintenance(perPage = 100)
                maintenanceList = m
                val (c, _) = APIService.fetchFleetCosts(perPage = 100)
                costsList = c
                val (d, _) = APIService.fetchFleetDocuments(perPage = 100)
                documentsList = d
                // Tires endpoint may not exist yet — handle gracefully
                try {
                    val tiresJson = APIService.get("/api/mobile/fleet/tires?per_page=100")
                    val dataArr = tiresJson.optJSONArray("data") ?: org.json.JSONArray()
                    tiresList = (0 until dataArr.length()).map { FleetTire.fromJson(dataArr.getJSONObject(it)) }
                } catch (_: Exception) {
                    tiresList = emptyList()
                }
            } catch (e: Exception) {
                errorMessage = e.localizedMessage ?: "Veri yüklenemedi"
            }
            isLoading = false
            isRefreshing = false
        }
    }

    LaunchedEffect(Unit) { loadAll() }

    // Filtered plate label for display
    val selectedPlateLabel = remember(selectedVehicleFilter, catalog) {
        if (selectedVehicleFilter == null) "Tüm Araçlar"
        else catalog.vehicles.find { it.imei == selectedVehicleFilter }?.plate ?: "Araç"
    }

    // Filter helper
    fun matchesFilter(imei: String, plate: String): Boolean {
        val matchesVehicle = selectedVehicleFilter == null || imei == selectedVehicleFilter
        val matchesSearch = searchText.isBlank() ||
                plate.contains(searchText, ignoreCase = true) ||
                imei.contains(searchText, ignoreCase = true)
        return matchesVehicle && matchesSearch
    }

    val filteredMaintenance = maintenanceList.filter { matchesFilter(it.imei, it.plate) }
    val filteredCosts = costsList.filter { matchesFilter(it.imei, it.plate) }
    val filteredDocuments = documentsList.filter { matchesFilter(it.imei, it.plate) }
    val filteredTires = tiresList.filter { matchesFilter(it.imei, it.plate) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Filo Yönetimi", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy) },
                actions = {
                    IconButton(onClick = {
                        editingMaintenance = null; editingCost = null; editingDocument = null; editingTire = null
                        showAddSheet = true
                    }) {
                        Icon(Icons.Default.Add, "Ekle", tint = AppColors.Indigo)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        }
    ) { padding ->
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = { loadAll() },
            modifier = Modifier.fillMaxSize().padding(padding)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(AppColors.Bg)
            ) {
                // Reminders Banner
                if (reminders.isNotEmpty()) {
                    RemindersBanner(reminders)
                }

                // Tab Selector
                FleetTabSelector(selectedTab) { selectedTab = it }

                // Search Bar + Vehicle Filter Row
                SearchFilterBar(
                    searchText = searchText,
                    onSearchChange = { searchText = it },
                    selectedPlateLabel = selectedPlateLabel,
                    showDropdown = showVehicleFilterDropdown,
                    onToggleDropdown = { showVehicleFilterDropdown = !showVehicleFilterDropdown },
                    onDismissDropdown = { showVehicleFilterDropdown = false },
                    vehicles = catalog.vehicles,
                    selectedVehicleFilter = selectedVehicleFilter,
                    onSelectVehicle = { imei ->
                        selectedVehicleFilter = imei
                        showVehicleFilterDropdown = false
                    }
                )

                // Content
                if (isLoading && maintenanceList.isEmpty()) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 2.dp, modifier = Modifier.size(28.dp))
                    }
                } else if (errorMessage != null) {
                    ErrorView(errorMessage!!) { loadAll() }
                } else {
                    when (selectedTab) {
                        FleetTab.MAINTENANCE -> MaintenanceListTab(
                            items = filteredMaintenance,
                            onEdit = { editingMaintenance = it; showAddSheet = true },
                            onDelete = { item ->
                                scope.launch {
                                    try {
                                        APIService.deleteFleetMaintenance(item.id.toIntOrNull() ?: 0)
                                        maintenanceList = maintenanceList.filter { it.id != item.id }
                                    } catch (_: Exception) {}
                                }
                            }
                        )
                        FleetTab.COSTS -> CostsListTab(
                            items = filteredCosts,
                            onEdit = { editingCost = it; showAddSheet = true },
                            onDelete = { item ->
                                scope.launch {
                                    try {
                                        APIService.deleteFleetCost(item.id.toIntOrNull() ?: 0)
                                        costsList = costsList.filter { it.id != item.id }
                                    } catch (_: Exception) {}
                                }
                            }
                        )
                        FleetTab.DOCUMENTS -> DocumentsListTab(
                            items = filteredDocuments,
                            onEdit = { editingDocument = it; showAddSheet = true },
                            onDelete = { item ->
                                scope.launch {
                                    try {
                                        APIService.deleteFleetDocument(item.id.toIntOrNull() ?: 0)
                                        documentsList = documentsList.filter { it.id != item.id }
                                    } catch (_: Exception) {}
                                }
                            }
                        )
                        FleetTab.TIRES -> TiresListTab(
                            items = filteredTires,
                            onEdit = { editingTire = it; showAddSheet = true },
                            onDelete = { item ->
                                scope.launch {
                                    try {
                                        APIService.httpDelete("/api/mobile/fleet/tires/${item.id}")
                                        tiresList = tiresList.filter { it.id != item.id }
                                    } catch (_: Exception) {}
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // Bottom Sheet for add/edit
    if (showAddSheet) {
        ModalBottomSheet(
            onDismissRequest = {
                showAddSheet = false
                editingMaintenance = null; editingCost = null; editingDocument = null; editingTire = null
            },
            containerColor = AppColors.Surface,
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp),
            tonalElevation = 0.dp,
            dragHandle = {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Spacer(Modifier.height(8.dp))
                    Box(
                        modifier = Modifier
                            .width(40.dp)
                            .height(4.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(AppColors.BorderSoft)
                    )
                    Spacer(Modifier.height(12.dp))
                }
            }
        ) {
            when (selectedTab) {
                FleetTab.MAINTENANCE -> MaintenanceFormSheet(
                    catalog = catalog,
                    editing = editingMaintenance,
                    onSaved = {
                        showAddSheet = false; editingMaintenance = null; loadAll()
                    },
                    onCancel = { showAddSheet = false; editingMaintenance = null }
                )
                FleetTab.COSTS -> CostFormSheet(
                    catalog = catalog,
                    editing = editingCost,
                    onSaved = {
                        showAddSheet = false; editingCost = null; loadAll()
                    },
                    onCancel = { showAddSheet = false; editingCost = null }
                )
                FleetTab.DOCUMENTS -> DocumentFormSheet(
                    catalog = catalog,
                    editing = editingDocument,
                    onSaved = {
                        showAddSheet = false; editingDocument = null; loadAll()
                    },
                    onCancel = { showAddSheet = false; editingDocument = null }
                )
                FleetTab.TIRES -> TireFormSheet(
                    catalog = catalog,
                    editing = editingTire,
                    onSaved = {
                        showAddSheet = false; editingTire = null; loadAll()
                    },
                    onCancel = { showAddSheet = false; editingTire = null }
                )
            }
        }
    }
}

// ============================================================================
// MARK: - Search & Filter Bar
// ============================================================================
@Composable
private fun SearchFilterBar(
    searchText: String,
    onSearchChange: (String) -> Unit,
    selectedPlateLabel: String,
    showDropdown: Boolean,
    onToggleDropdown: () -> Unit,
    onDismissDropdown: () -> Unit,
    vehicles: List<FleetCatalogVehicle>,
    selectedVehicleFilter: String?,
    onSelectVehicle: (String?) -> Unit
) {
    val focusManager = LocalFocusManager.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface)
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        // Search Row
        OutlinedTextField(
            value = searchText,
            onValueChange = onSearchChange,
            placeholder = { Text("Plaka ara...", fontSize = 13.sp, color = AppColors.TextFaint) },
            leadingIcon = { Icon(Icons.Default.Search, null, tint = AppColors.TextMuted, modifier = Modifier.size(18.dp)) },
            trailingIcon = {
                if (searchText.isNotEmpty()) {
                    IconButton(onClick = { onSearchChange("") }) {
                        Icon(Icons.Default.Close, null, tint = AppColors.TextMuted, modifier = Modifier.size(16.dp))
                    }
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, color = AppColors.Navy),
            singleLine = true,
            shape = RoundedCornerShape(10.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Indigo,
                unfocusedBorderColor = AppColors.BorderSoft,
                cursorColor = AppColors.Indigo
            ),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { focusManager.clearFocus() })
        )

        Spacer(Modifier.height(8.dp))

        // Vehicle Filter Chips
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box {
                FilterChip(
                    selected = selectedVehicleFilter != null,
                    onClick = onToggleDropdown,
                    label = { Text(selectedPlateLabel, fontSize = 12.sp, maxLines = 1) },
                    leadingIcon = { Icon(Icons.Default.DirectionsCar, null, modifier = Modifier.size(14.dp)) },
                    trailingIcon = { Icon(Icons.Default.ArrowDropDown, null, modifier = Modifier.size(14.dp)) },
                    shape = RoundedCornerShape(8.dp),
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = AppColors.Indigo.copy(alpha = 0.12f),
                        selectedLabelColor = AppColors.Indigo,
                        selectedLeadingIconColor = AppColors.Indigo
                    )
                )
                DropdownMenu(
                    expanded = showDropdown,
                    onDismissRequest = onDismissDropdown,
                    modifier = Modifier.heightIn(max = 300.dp)
                ) {
                    DropdownMenuItem(
                        text = { Text("Tüm Araçlar", fontSize = 13.sp, fontWeight = if (selectedVehicleFilter == null) FontWeight.Bold else FontWeight.Normal) },
                        onClick = { onSelectVehicle(null) },
                        leadingIcon = { Icon(Icons.Default.SelectAll, null, modifier = Modifier.size(16.dp)) }
                    )
                    HorizontalDivider(color = AppColors.BorderSoft)
                    vehicles.forEach { v ->
                        DropdownMenuItem(
                            text = {
                                Text(
                                    v.plate.ifEmpty { v.name },
                                    fontSize = 13.sp,
                                    fontWeight = if (selectedVehicleFilter == v.imei) FontWeight.Bold else FontWeight.Normal
                                )
                            },
                            onClick = { onSelectVehicle(v.imei) },
                            leadingIcon = { Icon(Icons.Default.DirectionsCar, null, modifier = Modifier.size(16.dp), tint = AppColors.TextMuted) }
                        )
                    }
                }
            }

            if (selectedVehicleFilter != null) {
                Spacer(Modifier.width(8.dp))
                AssistChip(
                    onClick = { onSelectVehicle(null) },
                    label = { Text("Temizle", fontSize = 11.sp) },
                    leadingIcon = { Icon(Icons.Default.Close, null, modifier = Modifier.size(12.dp)) },
                    shape = RoundedCornerShape(8.dp),
                    colors = AssistChipDefaults.assistChipColors(
                        containerColor = Color(0xFFFEE2E2),
                        labelColor = Color(0xFFEF4444),
                        leadingIconContentColor = Color(0xFFEF4444)
                    )
                )
            }
        }
    }
    HorizontalDivider(color = AppColors.BorderSoft, thickness = 0.5.dp)
}

// ============================================================================
// MARK: - Reminders Banner
// ============================================================================
@Composable
private fun RemindersBanner(reminders: List<FleetReminder>) {
    val urgentCount = reminders.count { it.daysLeft <= 7 }
    val warningCount = reminders.count { it.daysLeft in 8..30 }
    if (urgentCount == 0 && warningCount == 0) return

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp),
        shape = RoundedCornerShape(10.dp),
        color = if (urgentCount > 0) Color(0xFFFEF2F2) else Color(0xFFFFFBEB),
        border = BorderStroke(1.dp, if (urgentCount > 0) Color(0xFFFECACA) else Color(0xFFFDE68A))
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.Warning,
                null,
                tint = if (urgentCount > 0) Color(0xFFEF4444) else Color(0xFFF59E0B),
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    if (urgentCount > 0) "$urgentCount acil hatırlatıcı" else "$warningCount yaklaşan hatırlatıcı",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (urgentCount > 0) Color(0xFFDC2626) else Color(0xFFD97706)
                )
                Text(
                    "Belge süreleri ve bakım planlarını kontrol edin",
                    fontSize = 11.sp,
                    color = AppColors.TextMuted
                )
            }
        }
    }
}

// ============================================================================
// MARK: - Tab Selector
// ============================================================================
@Composable
private fun FleetTabSelector(selected: FleetTab, onSelect: (FleetTab) -> Unit) {
    ScrollableTabRow(
        selectedTabIndex = FleetTab.entries.indexOf(selected),
        containerColor = AppColors.Surface,
        contentColor = AppColors.Indigo,
        edgePadding = 8.dp,
        divider = { HorizontalDivider(color = AppColors.BorderSoft, thickness = 0.5.dp) }
    ) {
        FleetTab.entries.forEach { tab ->
            Tab(
                selected = selected == tab,
                onClick = { onSelect(tab) },
                selectedContentColor = AppColors.Indigo,
                unselectedContentColor = AppColors.TextMuted
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(tab.icon, null, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(tab.label, fontSize = 12.sp, fontWeight = if (selected == tab) FontWeight.SemiBold else FontWeight.Normal)
                }
            }
        }
    }
}

// ============================================================================
// MARK: - Maintenance List Tab
// ============================================================================
@Composable
private fun MaintenanceListTab(
    items: List<FleetMaintenance>,
    onEdit: (FleetMaintenance) -> Unit,
    onDelete: (FleetMaintenance) -> Unit
) {
    if (items.isEmpty()) {
        EmptyStateView("Bakım kaydı bulunamadı", Icons.Default.Build)
        return
    }
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(items, key = { it.id }) { item ->
            FleetCard(
                topLabel = item.plate,
                title = item.maintenanceType.replaceFirstChar { it.uppercase() },
                subtitle = item.workshop.ifEmpty { null },
                badge = item.statusLabel,
                badgeColor = item.statusColor,
                line1Icon = Icons.Default.CalendarToday,
                line1 = item.serviceDate ?: "—",
                line2Icon = Icons.Default.Speed,
                line2 = if (item.kmAtService != null) "${java.text.NumberFormat.getNumberInstance(java.util.Locale("tr","TR")).format(item.kmAtService)} km" else "—",
                line3Icon = Icons.Default.Paid,
                line3 = item.formattedCost,
                onEdit = { onEdit(item) },
                onDelete = { onDelete(item) }
            )
        }
    }
}

// ============================================================================
// MARK: - Costs List Tab
// ============================================================================
@Composable
private fun CostsListTab(
    items: List<VehicleCost>,
    onEdit: (VehicleCost) -> Unit,
    onDelete: (VehicleCost) -> Unit
) {
    if (items.isEmpty()) {
        EmptyStateView("Masraf kaydı bulunamadı", Icons.Default.Receipt)
        return
    }
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(items, key = { it.id }) { item ->
            FleetCard(
                topLabel = item.plate,
                title = item.category.replaceFirstChar { it.uppercase() },
                subtitle = item.description.ifEmpty { null },
                badge = item.formattedAmount,
                badgeColor = AppColors.Indigo,
                line1Icon = Icons.Default.CalendarToday,
                line1 = item.costDate.ifEmpty { "—" },
                line2Icon = Icons.Default.Tag,
                line2 = item.referenceNo.ifEmpty { "—" },
                onEdit = { onEdit(item) },
                onDelete = { onDelete(item) }
            )
        }
    }
}

// ============================================================================
// MARK: - Documents List Tab
// ============================================================================
@Composable
private fun DocumentsListTab(
    items: List<FleetDocument>,
    onEdit: (FleetDocument) -> Unit,
    onDelete: (FleetDocument) -> Unit
) {
    if (items.isEmpty()) {
        EmptyStateView("Belge kaydı bulunamadı", Icons.Default.Description)
        return
    }
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(items, key = { it.id }) { item ->
            val daysText = if (item.daysLeft != null) {
                if (item.daysLeft < 0) "Süresi ${-item.daysLeft} gün geçmiş"
                else if (item.daysLeft == 0) "Bugün doluyor"
                else "${item.daysLeft} gün kaldı"
            } else "—"
            FleetCard(
                topLabel = item.plate,
                title = item.docTypeLabel,
                subtitle = item.title.ifEmpty { null },
                badge = item.statusLabel,
                badgeColor = item.statusColor,
                line1Icon = Icons.Default.CalendarToday,
                line1 = item.expiryDate ?: "—",
                line2Icon = Icons.Default.Timer,
                line2 = daysText,
                onEdit = { onEdit(item) },
                onDelete = { onDelete(item) }
            )
        }
    }
}

// ============================================================================
// MARK: - Tires List Tab
// ============================================================================
@Composable
private fun TiresListTab(
    items: List<FleetTire>,
    onEdit: (FleetTire) -> Unit,
    onDelete: (FleetTire) -> Unit
) {
    if (items.isEmpty()) {
        EmptyStateView("Lastik kaydı bulunamadı", Icons.Default.TireRepair)
        return
    }
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(items, key = { it.id }) { item ->
            FleetCard(
                topLabel = item.plate,
                title = "${item.brand} ${item.model}".trim().ifEmpty { "Lastik" },
                subtitle = item.position.ifEmpty { null },
                badge = item.statusLabel,
                badgeColor = item.statusColor,
                line1Icon = Icons.Default.Straighten,
                line1 = item.size.ifEmpty { "—" },
                line2Icon = Icons.Default.Speed,
                line2 = if (item.kmAtInstall > 0) "${java.text.NumberFormat.getNumberInstance(java.util.Locale("tr","TR")).format(item.kmAtInstall)} km" else "—",
                line3Icon = Icons.Default.CalendarToday,
                line3 = item.installDate.ifEmpty { "—" },
                onEdit = { onEdit(item) },
                onDelete = { onDelete(item) }
            )
        }
    }
}

// ============================================================================
// MARK: - Fleet Card (Shared)
// ============================================================================
@Composable
private fun FleetCard(
    topLabel: String,
    title: String,
    subtitle: String?,
    badge: String,
    badgeColor: Color,
    line1Icon: ImageVector,
    line1: String,
    line2Icon: ImageVector? = null,
    line2: String? = null,
    line3Icon: ImageVector? = null,
    line3: String? = null,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        color = AppColors.Surface,
        border = BorderStroke(1.dp, AppColors.BorderSoft),
        shadowElevation = 1.dp
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Header row
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Plate badge
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = AppColors.Indigo.copy(alpha = 0.08f)
                ) {
                    Text(
                        topLabel.ifEmpty { "—" },
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = AppColors.Indigo
                    )
                }
                Spacer(Modifier.weight(1f))
                // Status badge
                Surface(
                    shape = RoundedCornerShape(6.dp),
                    color = badgeColor.copy(alpha = 0.12f)
                ) {
                    Text(
                        badge,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = badgeColor
                    )
                }
            }

            Spacer(Modifier.height(10.dp))

            // Title
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            if (!subtitle.isNullOrEmpty()) {
                Text(subtitle, fontSize = 12.sp, color = AppColors.TextMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }

            Spacer(Modifier.height(10.dp))

            // Info lines
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                InfoChip(line1Icon, line1)
                if (line2 != null && line2Icon != null) InfoChip(line2Icon, line2)
                if (line3 != null && line3Icon != null) InfoChip(line3Icon, line3)
            }

            Spacer(Modifier.height(10.dp))
            HorizontalDivider(color = AppColors.BorderSoft)
            Spacer(Modifier.height(8.dp))

            // Action buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(
                    onClick = onEdit,
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.Edit, null, modifier = Modifier.size(14.dp), tint = AppColors.Indigo)
                    Spacer(Modifier.width(4.dp))
                    Text("Düzenle", fontSize = 12.sp, color = AppColors.Indigo)
                }
                TextButton(
                    onClick = { showDeleteConfirm = true },
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.Delete, null, modifier = Modifier.size(14.dp), tint = Color(0xFFEF4444))
                    Spacer(Modifier.width(4.dp))
                    Text("Sil", fontSize = 12.sp, color = Color(0xFFEF4444))
                }
            }
        }
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("Silme Onayı", fontWeight = FontWeight.SemiBold) },
            text = { Text("Bu kaydı silmek istediğinize emin misiniz?") },
            confirmButton = {
                TextButton(onClick = { showDeleteConfirm = false; onDelete() }) {
                    Text("Sil", color = Color(0xFFEF4444))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text("İptal")
                }
            }
        )
    }
}

@Composable
private fun InfoChip(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, modifier = Modifier.size(12.dp), tint = AppColors.TextMuted)
        Spacer(Modifier.width(4.dp))
        Text(text, fontSize = 11.sp, color = AppColors.TextSecondary, maxLines = 1)
    }
}

// ============================================================================
// MARK: - Maintenance Form Sheet
// ============================================================================
@Composable
private fun MaintenanceFormSheet(
    catalog: FleetCatalog,
    editing: FleetMaintenance?,
    onSaved: () -> Unit,
    onCancel: () -> Unit
) {
    val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    var selectedImei by remember { mutableStateOf(editing?.imei ?: "") }
    var maintenanceType by remember { mutableStateOf(editing?.maintenanceType ?: "") }
    var serviceDate by remember { mutableStateOf(editing?.serviceDate ?: "") }
    var nextServiceDate by remember { mutableStateOf(editing?.nextServiceDate ?: "") }
    var kmAtService by remember { mutableStateOf(editing?.kmAtService?.toString() ?: "") }
    var nextServiceKm by remember { mutableStateOf(editing?.nextServiceKm?.toString() ?: "") }
    var cost by remember { mutableStateOf(editing?.cost?.toString() ?: "") }
    var workshop by remember { mutableStateOf(editing?.workshop ?: "") }
    var description by remember { mutableStateOf(editing?.description ?: "") }
    var status by remember { mutableStateOf(editing?.status ?: "done") }

    val isEditing = editing != null

    FormSheetContainer(
        title = if (isEditing) "Bakım Düzenle" else "Yeni Bakım",
        icon = Icons.Default.Build
    ) {
        // Section: Vehicle
        FormSectionHeader("Araç Bilgileri", Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        // Section: Maintenance Details
        FormSectionHeader("Bakım Detayları", Icons.Default.Build)
        FormTextField("Bakım Türü", maintenanceType, { maintenanceType = it }, placeholder = "Yağ değişimi, fren bakımı...")
        DropdownField("Durum", status, listOf("done" to "Tamamlandı", "scheduled" to "Planlandı", "overdue" to "Gecikmiş")) { status = it }
        FormTextField("Servis Tarihi", serviceDate, { serviceDate = it }, placeholder = "2025-01-15")
        FormTextField("Sonraki Servis Tarihi", nextServiceDate, { nextServiceDate = it }, placeholder = "2025-07-15")

        // Section: KM & Cost
        FormSectionHeader("Kilometre & Maliyet", Icons.Default.Speed)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField("Servis KM", kmAtService, { kmAtService = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
            FormTextField("Sonraki KM", nextServiceKm, { nextServiceKm = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField("Maliyet (₺)", cost, { cost = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Decimal)
            FormTextField("Servis Yeri", workshop, { workshop = it }, modifier = Modifier.weight(1f))
        }

        // Section: Notes
        FormSectionHeader("Notlar", Icons.Default.Notes)
        FormTextField("Açıklama", description, { description = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank() || maintenanceType.isBlank()) {
                error = "Araç ve bakım türü zorunludur"; return@SaveButton
            }
            isSaving = true; error = null
            scope.launch {
                try {
                    val body = mutableMapOf<String, Any>(
                        "imei" to selectedImei,
                        "maintenance_type" to maintenanceType,
                        "status" to status,
                        "workshop" to workshop,
                        "description" to description
                    )
                    if (serviceDate.isNotBlank()) body["service_date"] = serviceDate
                    if (nextServiceDate.isNotBlank()) body["next_service_date"] = nextServiceDate
                    if (kmAtService.isNotBlank()) body["km_at_service"] = kmAtService.toIntOrNull() ?: 0
                    if (nextServiceKm.isNotBlank()) body["next_service_km"] = nextServiceKm.toIntOrNull() ?: 0
                    if (cost.isNotBlank()) body["cost"] = cost.toDoubleOrNull() ?: 0.0

                    if (isEditing) {
                        APIService.updateFleetMaintenance(editing!!.id.toIntOrNull() ?: 0, body)
                    } else {
                        APIService.createFleetMaintenance(body)
                    }
                    onSaved()
                } catch (e: Exception) {
                    error = e.localizedMessage ?: "Kayıt başarısız"
                }
                isSaving = false
            }
        }
        Spacer(Modifier.height(32.dp))
    }
}

// ============================================================================
// MARK: - Cost Form Sheet
// ============================================================================
@Composable
private fun CostFormSheet(
    catalog: FleetCatalog,
    editing: VehicleCost?,
    onSaved: () -> Unit,
    onCancel: () -> Unit
) {
    val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    var selectedImei by remember { mutableStateOf(editing?.imei ?: "") }
    var category by remember { mutableStateOf(editing?.category ?: "") }
    var amount by remember { mutableStateOf(if (editing != null && editing.amount > 0) editing.amount.toString() else "") }
    var currency by remember { mutableStateOf(editing?.currency ?: "TRY") }
    var costDate by remember { mutableStateOf(editing?.costDate ?: "") }
    var description by remember { mutableStateOf(editing?.description ?: "") }
    var referenceNo by remember { mutableStateOf(editing?.referenceNo ?: "") }

    val isEditing = editing != null

    FormSheetContainer(
        title = if (isEditing) "Masraf Düzenle" else "Yeni Masraf",
        icon = Icons.Default.Receipt
    ) {
        FormSectionHeader("Araç Bilgileri", Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        FormSectionHeader("Masraf Detayları", Icons.Default.Receipt)
        if (catalog.costCategories.isNotEmpty()) {
            DropdownField("Kategori", category, catalog.costCategories.map { it to it.replaceFirstChar { c -> c.uppercase() } }) { category = it }
        } else {
            FormTextField("Kategori", category, { category = it }, placeholder = "Yakıt, sigorta, bakım...")
        }
        FormTextField("Tarih", costDate, { costDate = it }, placeholder = "2025-01-15")

        FormSectionHeader("Tutar", Icons.Default.Paid)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField("Tutar", amount, { amount = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Decimal)
            DropdownField("Para Birimi", currency, listOf("TRY" to "₺ TRY", "USD" to "$ USD", "EUR" to "€ EUR"), modifier = Modifier.weight(1f)) { currency = it }
        }

        FormSectionHeader("Ek Bilgiler", Icons.Default.Info)
        FormTextField("Referans No", referenceNo, { referenceNo = it })
        FormTextField("Açıklama", description, { description = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank() || category.isBlank()) {
                error = "Araç ve kategori zorunludur"; return@SaveButton
            }
            isSaving = true; error = null
            scope.launch {
                try {
                    val body = mutableMapOf<String, Any>(
                        "imei" to selectedImei,
                        "category" to category,
                        "amount" to (amount.toDoubleOrNull() ?: 0.0),
                        "currency" to currency,
                        "cost_date" to costDate,
                        "description" to description,
                        "reference_no" to referenceNo
                    )
                    if (isEditing) {
                        APIService.updateFleetCost(editing!!.id.toIntOrNull() ?: 0, body)
                    } else {
                        APIService.createFleetCost(body)
                    }
                    onSaved()
                } catch (e: Exception) {
                    error = e.localizedMessage ?: "Kayıt başarısız"
                }
                isSaving = false
            }
        }
        Spacer(Modifier.height(32.dp))
    }
}

// ============================================================================
// MARK: - Document Form Sheet
// ============================================================================
@Composable
private fun DocumentFormSheet(
    catalog: FleetCatalog,
    editing: FleetDocument?,
    onSaved: () -> Unit,
    onCancel: () -> Unit
) {
    val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    var selectedImei by remember { mutableStateOf(editing?.imei ?: "") }
    var docType by remember { mutableStateOf(editing?.docType ?: "") }
    var title by remember { mutableStateOf(editing?.title ?: "") }
    var issueDate by remember { mutableStateOf(editing?.issueDate ?: "") }
    var expiryDate by remember { mutableStateOf(editing?.expiryDate ?: "") }
    var reminderDays by remember { mutableStateOf(editing?.reminderDays?.toString() ?: "30") }
    var notes by remember { mutableStateOf(editing?.notes ?: "") }

    val isEditing = editing != null

    FormSheetContainer(
        title = if (isEditing) "Belge Düzenle" else "Yeni Belge",
        icon = Icons.Default.Description
    ) {
        FormSectionHeader("Araç Bilgileri", Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        FormSectionHeader("Belge Bilgileri", Icons.Default.Description)
        if (catalog.documentTypes.isNotEmpty()) {
            DropdownField("Belge Türü", docType, catalog.documentTypes.map { it to it.replaceFirstChar { c -> c.uppercase() } }) { docType = it }
        } else {
            FormTextField("Belge Türü", docType, { docType = it }, placeholder = "ruhsat, sigorta, muayene...")
        }
        FormTextField("Başlık", title, { title = it })

        FormSectionHeader("Tarihler", Icons.Default.CalendarMonth)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField("Düzenleme Tarihi", issueDate, { issueDate = it }, modifier = Modifier.weight(1f), placeholder = "2025-01-15")
            FormTextField("Bitiş Tarihi", expiryDate, { expiryDate = it }, modifier = Modifier.weight(1f), placeholder = "2026-01-15")
        }
        FormTextField("Hatırlatma (gün)", reminderDays, { reminderDays = it }, keyboardType = KeyboardType.Number)

        FormSectionHeader("Notlar", Icons.Default.Notes)
        FormTextField("Notlar", notes, { notes = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank() || docType.isBlank()) {
                error = "Araç ve belge türü zorunludur"; return@SaveButton
            }
            isSaving = true; error = null
            scope.launch {
                try {
                    val body = mutableMapOf<String, Any>(
                        "imei" to selectedImei,
                        "doc_type" to docType,
                        "title" to title,
                        "reminder_days" to (reminderDays.toIntOrNull() ?: 30),
                        "notes" to notes
                    )
                    if (issueDate.isNotBlank()) body["issue_date"] = issueDate
                    if (expiryDate.isNotBlank()) body["expiry_date"] = expiryDate

                    if (isEditing) {
                        APIService.updateFleetDocument(editing!!.id.toIntOrNull() ?: 0, body)
                    } else {
                        APIService.createFleetDocument(body)
                    }
                    onSaved()
                } catch (e: Exception) {
                    error = e.localizedMessage ?: "Kayıt başarısız"
                }
                isSaving = false
            }
        }
        Spacer(Modifier.height(32.dp))
    }
}

// ============================================================================
// MARK: - Tire Form Sheet
// ============================================================================
@Composable
private fun TireFormSheet(
    catalog: FleetCatalog,
    editing: FleetTire?,
    onSaved: () -> Unit,
    onCancel: () -> Unit
) {
    val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    var selectedImei by remember { mutableStateOf(editing?.imei ?: "") }
    var position by remember { mutableStateOf(editing?.position ?: "") }
    var brand by remember { mutableStateOf(editing?.brand ?: "") }
    var model by remember { mutableStateOf(editing?.model ?: "") }
    var size by remember { mutableStateOf(editing?.size ?: "") }
    var dotCode by remember { mutableStateOf(editing?.dotCode ?: "") }
    var installDate by remember { mutableStateOf(editing?.installDate ?: "") }
    var kmAtInstall by remember { mutableStateOf(if (editing != null && editing.kmAtInstall > 0) editing.kmAtInstall.toString() else "") }
    var kmLimit by remember { mutableStateOf(if (editing != null && editing.kmLimit > 0) editing.kmLimit.toString() else "") }
    var status by remember { mutableStateOf(editing?.status ?: "active") }
    var notes by remember { mutableStateOf(editing?.notes ?: "") }

    val isEditing = editing != null
    val tirePositions = listOf(
        "sol_on" to "Sol Ön", "sag_on" to "Sağ Ön",
        "sol_arka" to "Sol Arka", "sag_arka" to "Sağ Arka",
        "yedek" to "Yedek"
    )

    FormSheetContainer(
        title = if (isEditing) "Lastik Düzenle" else "Yeni Lastik",
        icon = Icons.Default.TireRepair
    ) {
        FormSectionHeader("Araç Bilgileri", Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        FormSectionHeader("Lastik Bilgileri", Icons.Default.TireRepair)
        DropdownField("Pozisyon", position, tirePositions) { position = it }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField("Marka", brand, { brand = it }, modifier = Modifier.weight(1f))
            FormTextField("Model", model, { model = it }, modifier = Modifier.weight(1f))
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField("Ebat", size, { size = it }, modifier = Modifier.weight(1f), placeholder = "205/55R16")
            FormTextField("DOT Kodu", dotCode, { dotCode = it }, modifier = Modifier.weight(1f))
        }

        FormSectionHeader("Kilometre & Tarih", Icons.Default.Speed)
        FormTextField("Montaj Tarihi", installDate, { installDate = it }, placeholder = "2025-01-15")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField("Montaj KM", kmAtInstall, { kmAtInstall = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
            FormTextField("KM Limiti", kmLimit, { kmLimit = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
        }
        DropdownField("Durum", status, listOf("active" to "Aktif", "worn" to "Aşınmış", "replaced" to "Değiştirildi", "critical" to "Kritik")) { status = it }

        FormSectionHeader("Notlar", Icons.Default.Notes)
        FormTextField("Notlar", notes, { notes = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank()) {
                error = "Araç seçimi zorunludur"; return@SaveButton
            }
            isSaving = true; error = null
            scope.launch {
                try {
                    val body = mutableMapOf<String, Any>(
                        "imei" to selectedImei,
                        "position" to position,
                        "brand" to brand,
                        "model" to model,
                        "size" to size,
                        "dot_code" to dotCode,
                        "install_date" to installDate,
                        "status" to status,
                        "notes" to notes
                    )
                    if (kmAtInstall.isNotBlank()) body["km_at_install"] = kmAtInstall.toIntOrNull() ?: 0
                    if (kmLimit.isNotBlank()) body["km_limit"] = kmLimit.toIntOrNull() ?: 0

                    if (isEditing) {
                        APIService.put("/api/mobile/fleet/tires/${editing!!.id}", JSONObject(body as Map<*, *>))
                    } else {
                        APIService.post("/api/mobile/fleet/tires", JSONObject(body as Map<*, *>))
                    }
                    onSaved()
                } catch (e: Exception) {
                    error = e.localizedMessage ?: "Kayıt başarısız"
                }
                isSaving = false
            }
        }
        Spacer(Modifier.height(32.dp))
    }
}

// ============================================================================
// MARK: - Form Components
// ============================================================================
@Composable
private fun FormSheetContainer(
    title: String,
    icon: ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
    ) {
        // Title with icon
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(AppColors.Indigo.copy(alpha = 0.1f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
            }
            Spacer(Modifier.width(12.dp))
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }
        Spacer(Modifier.height(20.dp))
        content()
    }
}

@Composable
private fun FormSectionHeader(title: String, icon: ImageVector) {
    Spacer(Modifier.height(16.dp))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(6.dp))
        Text(
            title.uppercase(),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            color = AppColors.TextMuted,
            letterSpacing = 0.5.sp
        )
    }
    Spacer(Modifier.height(8.dp))
}

@Composable
private fun FormTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    keyboardType: KeyboardType = KeyboardType.Text,
    maxLines: Int = 1
) {
    Column(modifier = modifier.padding(bottom = 8.dp)) {
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
        Spacer(Modifier.height(4.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = {
                if (placeholder.isNotEmpty()) Text(placeholder, fontSize = 13.sp, color = AppColors.TextFaint)
            },
            modifier = Modifier.fillMaxWidth(),
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, color = AppColors.Navy),
            singleLine = maxLines == 1,
            maxLines = maxLines,
            shape = RoundedCornerShape(10.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Indigo,
                unfocusedBorderColor = AppColors.BorderSoft,
                cursorColor = AppColors.Indigo,
                focusedContainerColor = Color.White,
                unfocusedContainerColor = Color(0xFFFAFBFE)
            ),
            keyboardOptions = KeyboardOptions(keyboardType = keyboardType)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DropdownField(
    label: String,
    selectedValue: String,
    options: List<Pair<String, String>>, // value to display
    modifier: Modifier = Modifier,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val displayText = options.find { it.first == selectedValue }?.second ?: selectedValue.ifEmpty { "Seçiniz" }

    Column(modifier = modifier.padding(bottom = 8.dp)) {
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
        Spacer(Modifier.height(4.dp))
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = !expanded }
        ) {
            OutlinedTextField(
                value = displayText,
                onValueChange = {},
                readOnly = true,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier.fillMaxWidth().menuAnchor(),
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, color = AppColors.Navy),
                singleLine = true,
                shape = RoundedCornerShape(10.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AppColors.Indigo,
                    unfocusedBorderColor = AppColors.BorderSoft,
                    focusedContainerColor = Color.White,
                    unfocusedContainerColor = Color(0xFFFAFBFE)
                )
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { (value, display) ->
                    DropdownMenuItem(
                        text = { Text(display, fontSize = 13.sp) },
                        onClick = { onSelect(value); expanded = false }
                    )
                }
            }
        }
    }
}

@Composable
private fun VehiclePicker(
    vehicles: List<FleetCatalogVehicle>,
    selectedImei: String,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    var vehicleSearch by remember { mutableStateOf("") }
    val selectedPlate = vehicles.find { it.imei == selectedImei }?.plate ?: ""
    val filteredVehicles = if (vehicleSearch.isBlank()) vehicles
    else vehicles.filter {
        it.plate.contains(vehicleSearch, ignoreCase = true) || it.name.contains(vehicleSearch, ignoreCase = true)
    }

    Column(modifier = Modifier.padding(bottom = 8.dp)) {
        Text("Araç Seçimi", fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
        Spacer(Modifier.height(4.dp))
        Box {
            OutlinedTextField(
                value = selectedPlate.ifEmpty { "Araç seçiniz..." },
                onValueChange = {},
                readOnly = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = true },
                textStyle = androidx.compose.ui.text.TextStyle(
                    fontSize = 13.sp,
                    color = if (selectedPlate.isNotEmpty()) AppColors.Navy else AppColors.TextFaint
                ),
                singleLine = true,
                enabled = false,
                shape = RoundedCornerShape(10.dp),
                leadingIcon = { Icon(Icons.Default.DirectionsCar, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp)) },
                colors = OutlinedTextFieldDefaults.colors(
                    disabledBorderColor = AppColors.BorderSoft,
                    disabledTextColor = if (selectedPlate.isNotEmpty()) AppColors.Navy else AppColors.TextFaint,
                    disabledContainerColor = Color(0xFFFAFBFE),
                    disabledLeadingIconColor = AppColors.Indigo
                )
            )

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false; vehicleSearch = "" },
                modifier = Modifier
                    .fillMaxWidth(0.9f)
                    .heightIn(max = 300.dp)
            ) {
                // Search inside dropdown
                OutlinedTextField(
                    value = vehicleSearch,
                    onValueChange = { vehicleSearch = it },
                    placeholder = { Text("Plaka ara...", fontSize = 12.sp, color = AppColors.TextFaint) },
                    leadingIcon = { Icon(Icons.Default.Search, null, modifier = Modifier.size(16.dp), tint = AppColors.TextMuted) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                        .height(40.dp),
                    textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp),
                    singleLine = true,
                    shape = RoundedCornerShape(8.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Indigo,
                        unfocusedBorderColor = AppColors.BorderSoft
                    )
                )
                HorizontalDivider(color = AppColors.BorderSoft)
                filteredVehicles.forEach { v ->
                    DropdownMenuItem(
                        text = {
                            Column {
                                Text(v.plate, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                                if (v.name.isNotEmpty()) {
                                    Text(v.name, fontSize = 11.sp, color = AppColors.TextMuted)
                                }
                            }
                        },
                        onClick = {
                            onSelect(v.imei)
                            expanded = false
                            vehicleSearch = ""
                        },
                        leadingIcon = {
                            Icon(
                                Icons.Default.DirectionsCar, null,
                                modifier = Modifier.size(16.dp),
                                tint = if (v.imei == selectedImei) AppColors.Indigo else AppColors.TextMuted
                            )
                        }
                    )
                }
                if (filteredVehicles.isEmpty()) {
                    Text(
                        "Araç bulunamadı",
                        modifier = Modifier.padding(16.dp),
                        fontSize = 12.sp,
                        color = AppColors.TextMuted
                    )
                }
            }

            // Invisible clickable overlay
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .clickable { expanded = true }
            )
        }
    }
}

@Composable
private fun SaveButton(isEditing: Boolean, isSaving: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = !isSaving,
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp),
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AppColors.Indigo,
            disabledContainerColor = AppColors.Indigo.copy(alpha = 0.5f)
        )
    ) {
        if (isSaving) {
            CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
        }
        Icon(
            if (isEditing) Icons.Default.Save else Icons.Default.Add,
            null,
            modifier = Modifier.size(16.dp)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            if (isSaving) "Kaydediliyor..." else if (isEditing) "Güncelle" else "Kaydet",
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp
        )
    }
}

// ============================================================================
// MARK: - Empty State & Error Views
// ============================================================================
@Composable
private fun EmptyStateView(message: String, icon: ImageVector) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 80.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .background(AppColors.Indigo.copy(alpha = 0.08f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = AppColors.Indigo.copy(alpha = 0.5f), modifier = Modifier.size(28.dp))
        }
        Spacer(Modifier.height(16.dp))
        Text(message, fontSize = 14.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center)
    }
}

@Composable
private fun ErrorView(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 80.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(Icons.Default.ErrorOutline, null, tint = Color(0xFFEF4444), modifier = Modifier.size(40.dp))
        Spacer(Modifier.height(12.dp))
        Text(message, fontSize = 13.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = onRetry, shape = RoundedCornerShape(8.dp)) {
            Icon(Icons.Default.Refresh, null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text("Tekrar Dene", fontSize = 13.sp)
        }
    }
}
