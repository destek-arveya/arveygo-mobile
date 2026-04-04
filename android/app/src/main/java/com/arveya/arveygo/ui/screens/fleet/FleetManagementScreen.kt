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
import com.arveya.arveygo.utils.DashboardStrings
import kotlinx.coroutines.launch
import org.json.JSONObject

// ============================================================================
// MARK: - Tab Enum
// ============================================================================
enum class FleetTab(val icon: ImageVector) {
    MAINTENANCE(Icons.Default.Build),
    COSTS(Icons.Default.Receipt),
    DOCUMENTS(Icons.Default.Description),
    TIRES(Icons.Default.TireRepair);

    val label: String
        get() = when (this) {
            MAINTENANCE -> DashboardStrings.t("Bakım", "Maintenance", "Mantenimiento", "Maintenance")
            COSTS -> DashboardStrings.t("Masraf", "Expense", "Gasto", "Dépense")
            DOCUMENTS -> DashboardStrings.t("Belge", "Document", "Documento", "Document")
            TIRES -> DashboardStrings.t("Lastik", "Tire", "Neumático", "Pneu")
        }
}

// ============================================================================
// MARK: - FleetManagementScreen
// ============================================================================
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FleetManagementScreen() {
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
                errorMessage = e.localizedMessage ?: DL.t("Veri yüklenemedi", "Failed to load data", "No se pudieron cargar los datos", "Chargement des données impossible")
            }
            isLoading = false
            isRefreshing = false
        }
    }

    LaunchedEffect(Unit) { loadAll() }

    // Filtered plate label for display
    val selectedPlateLabel = remember(selectedVehicleFilter, catalog) {
        if (selectedVehicleFilter == null) DL.t("Tüm Araçlar", "All Vehicles", "Todos los vehículos", "Tous les véhicules")
        else catalog.vehicles.find { it.imei == selectedVehicleFilter }?.plate ?: DL.t("Araç", "Vehicle", "Vehículo", "Véhicule")
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
                title = { Text(DL.t("Filo Yönetimi", "Fleet Management", "Gestión de flota", "Gestion de flotte"), fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface) },
                actions = {
                    IconButton(onClick = {
                        editingMaintenance = null; editingCost = null; editingDocument = null; editingTire = null
                        showAddSheet = true
                    }) {
                        Icon(Icons.Default.Add, DL.t("Ekle", "Add", "Agregar", "Ajouter"), tint = AppColors.Indigo)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
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
                    .background(MaterialTheme.colorScheme.background)
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
            containerColor = MaterialTheme.colorScheme.surface,
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
                            .background(MaterialTheme.colorScheme.outline)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    val focusManager = LocalFocusManager.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        // Search Row
        OutlinedTextField(
            value = searchText,
            onValueChange = onSearchChange,
            placeholder = { Text(DL.t("Plaka ara...", "Search plate...", "Buscar matrícula...", "Rechercher une plaque..."), fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)) },
            leadingIcon = { Icon(Icons.Default.Search, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(18.dp)) },
            trailingIcon = {
                if (searchText.isNotEmpty()) {
                    IconButton(onClick = { onSearchChange("") }) {
                        Icon(Icons.Default.Close, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), modifier = Modifier.size(16.dp))
                    }
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface),
            singleLine = true,
            shape = RoundedCornerShape(10.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Indigo,
                unfocusedBorderColor = MaterialTheme.colorScheme.outline,
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
                        text = { Text(DL.t("Tüm Araçlar", "All Vehicles", "Todos los vehículos", "Tous les véhicules"), fontSize = 13.sp, fontWeight = if (selectedVehicleFilter == null) FontWeight.Bold else FontWeight.Normal) },
                        onClick = { onSelectVehicle(null) },
                        leadingIcon = { Icon(Icons.Default.SelectAll, null, modifier = Modifier.size(16.dp)) }
                    )
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline)
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
                            leadingIcon = { Icon(Icons.Default.DirectionsCar, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)) }
                        )
                    }
                }
            }

            if (selectedVehicleFilter != null) {
                Spacer(Modifier.width(8.dp))
                AssistChip(
                    onClick = { onSelectVehicle(null) },
                    label = { Text(DL.t("Temizle", "Clear", "Limpiar", "Effacer"), fontSize = 11.sp) },
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
    HorizontalDivider(color = MaterialTheme.colorScheme.outline, thickness = 0.5.dp)
}

// ============================================================================
// MARK: - Reminders Banner
// ============================================================================
@Composable
private fun RemindersBanner(reminders: List<FleetReminder>) {
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
                    if (urgentCount > 0) DL.t("$urgentCount acil hatırlatıcı", "$urgentCount urgent reminders", "$urgentCount recordatorios urgentes", "$urgentCount rappels urgents")
                    else DL.t("$warningCount yaklaşan hatırlatıcı", "$warningCount upcoming reminders", "$warningCount recordatorios próximos", "$warningCount rappels à venir"),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = if (urgentCount > 0) Color(0xFFDC2626) else Color(0xFFD97706)
                )
                Text(
                    DL.t("Belge süreleri ve bakım planlarını kontrol edin", "Check document deadlines and maintenance plans", "Revise vencimientos de documentos y planes de mantenimiento", "Vérifiez les échéances des documents et les plans d'entretien"),
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
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
        containerColor = MaterialTheme.colorScheme.surface,
        contentColor = AppColors.Indigo,
        edgePadding = 8.dp,
        divider = { HorizontalDivider(color = MaterialTheme.colorScheme.outline, thickness = 0.5.dp) }
    ) {
        FleetTab.entries.forEach { tab ->
            Tab(
                selected = selected == tab,
                onClick = { onSelect(tab) },
                selectedContentColor = AppColors.Indigo,
                unselectedContentColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    if (items.isEmpty()) {
        EmptyStateView(DL.t("Bakım kaydı bulunamadı", "No maintenance records found", "No se encontraron registros de mantenimiento", "Aucun entretien trouvé"), Icons.Default.Build)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    if (items.isEmpty()) {
        EmptyStateView(DL.t("Masraf kaydı bulunamadı", "No expense records found", "No se encontraron registros de gastos", "Aucune dépense trouvée"), Icons.Default.Receipt)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    if (items.isEmpty()) {
        EmptyStateView(DL.t("Belge kaydı bulunamadı", "No document records found", "No se encontraron documentos", "Aucun document trouvé"), Icons.Default.Description)
        return
    }
    LazyColumn(
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(items, key = { it.id }) { item ->
            val daysText = if (item.daysLeft != null) {
                if (item.daysLeft < 0) DL.t("Süresi ${-item.daysLeft} gün geçmiş", "Expired ${-item.daysLeft} days ago", "Venció hace ${-item.daysLeft} días", "Expiré depuis ${-item.daysLeft} jours")
                else if (item.daysLeft == 0) DL.t("Bugün doluyor", "Expires today", "Vence hoy", "Expire aujourd'hui")
                else DL.t("${item.daysLeft} gün kaldı", "${item.daysLeft} days left", "Quedan ${item.daysLeft} días", "Il reste ${item.daysLeft} jours")
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    if (items.isEmpty()) {
        EmptyStateView(DL.t("Lastik kaydı bulunamadı", "No tire records found", "No se encontraron neumáticos", "Aucun pneu trouvé"), Icons.Default.TireRepair)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    var showDeleteConfirm by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
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
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
            if (!subtitle.isNullOrEmpty()) {
                Text(subtitle, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), maxLines = 1, overflow = TextOverflow.Ellipsis)
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
            HorizontalDivider(color = MaterialTheme.colorScheme.outline)
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
                    Text(DL.t("Düzenle", "Edit", "Editar", "Modifier"), fontSize = 12.sp, color = AppColors.Indigo)
                }
                TextButton(
                    onClick = { showDeleteConfirm = true },
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    Icon(Icons.Default.Delete, null, modifier = Modifier.size(14.dp), tint = Color(0xFFEF4444))
                    Spacer(Modifier.width(4.dp))
                    Text(DL.t("Sil", "Delete", "Eliminar", "Supprimer"), fontSize = 12.sp, color = Color(0xFFEF4444))
                }
            }
        }
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(DL.t("Silme Onayı", "Delete Confirmation", "Confirmación de eliminación", "Confirmation de suppression"), fontWeight = FontWeight.SemiBold) },
            text = { Text(DL.t("Bu kaydı silmek istediğinize emin misiniz?", "Are you sure you want to delete this record?", "¿Seguro que desea eliminar este registro?", "Voulez-vous vraiment supprimer cet enregistrement ?")) },
            confirmButton = {
                TextButton(onClick = { showDeleteConfirm = false; onDelete() }) {
                    Text(DL.t("Sil", "Delete", "Eliminar", "Supprimer"), color = Color(0xFFEF4444))
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text(DL.t("İptal", "Cancel", "Cancelar", "Annuler"))
                }
            }
        )
    }
}

@Composable
private fun InfoChip(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, modifier = Modifier.size(12.dp), tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
        Spacer(Modifier.width(4.dp))
        Text(text, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f), maxLines = 1)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
        title = if (isEditing) DL.t("Bakım Düzenle", "Edit Maintenance", "Editar mantenimiento", "Modifier l'entretien") else DL.t("Yeni Bakım", "New Maintenance", "Nuevo mantenimiento", "Nouvel entretien"),
        icon = Icons.Default.Build
    ) {
        // Section: Vehicle
        FormSectionHeader(DL.t("Araç Bilgileri", "Vehicle Information", "Información del vehículo", "Informations du véhicule"), Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        // Section: Maintenance Details
        FormSectionHeader(DL.t("Bakım Detayları", "Maintenance Details", "Detalles de mantenimiento", "Détails de l'entretien"), Icons.Default.Build)
        FormTextField(DL.t("Bakım Türü", "Maintenance Type", "Tipo de mantenimiento", "Type d'entretien"), maintenanceType, { maintenanceType = it }, placeholder = DL.t("Yağ değişimi, fren bakımı...", "Oil change, brake service...", "Cambio de aceite, frenos...", "Vidange, entretien des freins..."))
        DropdownField(DL.t("Durum", "Status", "Estado", "Statut"), status, listOf(
            "done" to DL.t("Tamamlandı", "Completed", "Completado", "Terminé"),
            "scheduled" to DL.t("Planlandı", "Scheduled", "Programado", "Planifié"),
            "overdue" to DL.t("Gecikmiş", "Overdue", "Atrasado", "En retard")
        )) { status = it }
        FormTextField(DL.t("Servis Tarihi", "Service Date", "Fecha de servicio", "Date d'entretien"), serviceDate, { serviceDate = it }, placeholder = "2025-01-15")
        FormTextField(DL.t("Sonraki Servis Tarihi", "Next Service Date", "Próxima fecha de servicio", "Prochaine date d'entretien"), nextServiceDate, { nextServiceDate = it }, placeholder = "2025-07-15")

        // Section: KM & Cost
        FormSectionHeader(DL.t("Kilometre ve Maliyet", "Mileage & Cost", "Kilometraje y costo", "Kilométrage et coût"), Icons.Default.Speed)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField(DL.t("Servis KM", "Service KM", "KM de servicio", "KM entretien"), kmAtService, { kmAtService = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
            FormTextField(DL.t("Sonraki KM", "Next KM", "Próximo KM", "KM suivant"), nextServiceKm, { nextServiceKm = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField(DL.t("Maliyet (₺)", "Cost (₺)", "Costo (₺)", "Coût (₺)"), cost, { cost = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Decimal)
            FormTextField(DL.t("Servis Yeri", "Workshop", "Taller", "Atelier"), workshop, { workshop = it }, modifier = Modifier.weight(1f))
        }

        // Section: Notes
        FormSectionHeader(DL.t("Notlar", "Notes", "Notas", "Notes"), Icons.Default.Notes)
        FormTextField(DL.t("Açıklama", "Description", "Descripción", "Description"), description, { description = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank() || maintenanceType.isBlank()) {
                error = DL.t("Araç ve bakım türü zorunludur", "Vehicle and maintenance type are required", "El vehículo y el tipo de mantenimiento son obligatorios", "Le véhicule et le type d'entretien sont requis"); return@SaveButton
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
                    error = e.localizedMessage ?: DL.t("Kayıt başarısız", "Save failed", "Error al guardar", "Échec de l'enregistrement")
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
        title = if (isEditing) DL.t("Masraf Düzenle", "Edit Expense", "Editar gasto", "Modifier la dépense") else DL.t("Yeni Masraf", "New Expense", "Nuevo gasto", "Nouvelle dépense"),
        icon = Icons.Default.Receipt
    ) {
        FormSectionHeader(DL.t("Araç Bilgileri", "Vehicle Information", "Información del vehículo", "Informations du véhicule"), Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        FormSectionHeader(DL.t("Masraf Detayları", "Expense Details", "Detalles del gasto", "Détails de la dépense"), Icons.Default.Receipt)
        if (catalog.costCategories.isNotEmpty()) {
            DropdownField(DL.t("Kategori", "Category", "Categoría", "Catégorie"), category, catalog.costCategories.map { it to it.replaceFirstChar { c -> c.uppercase() } }) { category = it }
        } else {
            FormTextField(DL.t("Kategori", "Category", "Categoría", "Catégorie"), category, { category = it }, placeholder = DL.t("Yakıt, sigorta, bakım...", "Fuel, insurance, maintenance...", "Combustible, seguro, mantenimiento...", "Carburant, assurance, entretien..."))
        }
        FormTextField(DL.t("Tarih", "Date", "Fecha", "Date"), costDate, { costDate = it }, placeholder = "2025-01-15")

        FormSectionHeader(DL.t("Tutar", "Amount", "Importe", "Montant"), Icons.Default.Paid)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField(DL.t("Tutar", "Amount", "Importe", "Montant"), amount, { amount = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Decimal)
            DropdownField(DL.t("Para Birimi", "Currency", "Moneda", "Devise"), currency, listOf("TRY" to "₺ TRY", "USD" to "$ USD", "EUR" to "€ EUR"), modifier = Modifier.weight(1f)) { currency = it }
        }

        FormSectionHeader(DL.t("Ek Bilgiler", "Additional Information", "Información adicional", "Informations supplémentaires"), Icons.Default.Info)
        FormTextField(DL.t("Referans No", "Reference No", "N.º de referencia", "N° de référence"), referenceNo, { referenceNo = it })
        FormTextField(DL.t("Açıklama", "Description", "Descripción", "Description"), description, { description = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank() || category.isBlank()) {
                error = DL.t("Araç ve kategori zorunludur", "Vehicle and category are required", "El vehículo y la categoría son obligatorios", "Le véhicule et la catégorie sont requis"); return@SaveButton
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
                    error = e.localizedMessage ?: DL.t("Kayıt başarısız", "Save failed", "Error al guardar", "Échec de l'enregistrement")
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
        title = if (isEditing) DL.t("Belge Düzenle", "Edit Document", "Editar documento", "Modifier le document") else DL.t("Yeni Belge", "New Document", "Nuevo documento", "Nouveau document"),
        icon = Icons.Default.Description
    ) {
        FormSectionHeader(DL.t("Araç Bilgileri", "Vehicle Information", "Información del vehículo", "Informations du véhicule"), Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        FormSectionHeader(DL.t("Belge Bilgileri", "Document Information", "Información del documento", "Informations du document"), Icons.Default.Description)
        if (catalog.documentTypes.isNotEmpty()) {
            DropdownField(DL.t("Belge Türü", "Document Type", "Tipo de documento", "Type de document"), docType, catalog.documentTypes.map { it to it.replaceFirstChar { c -> c.uppercase() } }) { docType = it }
        } else {
            FormTextField(DL.t("Belge Türü", "Document Type", "Tipo de documento", "Type de document"), docType, { docType = it }, placeholder = DL.t("ruhsat, sigorta, muayene...", "registration, insurance, inspection...", "registro, seguro, inspección...", "carte grise, assurance, contrôle technique..."))
        }
        FormTextField(DL.t("Başlık", "Title", "Título", "Titre"), title, { title = it })

        FormSectionHeader(DL.t("Tarihler", "Dates", "Fechas", "Dates"), Icons.Default.CalendarMonth)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField(DL.t("Düzenleme Tarihi", "Issue Date", "Fecha de emisión", "Date d'émission"), issueDate, { issueDate = it }, modifier = Modifier.weight(1f), placeholder = "2025-01-15")
            FormTextField(DL.t("Bitiş Tarihi", "Expiry Date", "Fecha de vencimiento", "Date d'expiration"), expiryDate, { expiryDate = it }, modifier = Modifier.weight(1f), placeholder = "2026-01-15")
        }
        FormTextField(DL.t("Hatırlatma (gün)", "Reminder (days)", "Recordatorio (días)", "Rappel (jours)"), reminderDays, { reminderDays = it }, keyboardType = KeyboardType.Number)

        FormSectionHeader(DL.t("Notlar", "Notes", "Notas", "Notes"), Icons.Default.Notes)
        FormTextField(DL.t("Notlar", "Notes", "Notas", "Notes"), notes, { notes = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank() || docType.isBlank()) {
                error = DL.t("Araç ve belge türü zorunludur", "Vehicle and document type are required", "El vehículo y el tipo de documento son obligatorios", "Le véhicule et le type de document sont requis"); return@SaveButton
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
                    error = e.localizedMessage ?: DL.t("Kayıt başarısız", "Save failed", "Error al guardar", "Échec de l'enregistrement")
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
        "sol_on" to DL.t("Sol Ön", "Front Left", "Delantera izquierda", "Avant gauche"),
        "sag_on" to DL.t("Sağ Ön", "Front Right", "Delantera derecha", "Avant droite"),
        "sol_arka" to DL.t("Sol Arka", "Rear Left", "Trasera izquierda", "Arrière gauche"),
        "sag_arka" to DL.t("Sağ Arka", "Rear Right", "Trasera derecha", "Arrière droite"),
        "yedek" to DL.t("Yedek", "Spare", "Repuesto", "Secours")
    )

    FormSheetContainer(
        title = if (isEditing) DL.t("Lastik Düzenle", "Edit Tire", "Editar neumático", "Modifier le pneu") else DL.t("Yeni Lastik", "New Tire", "Nuevo neumático", "Nouveau pneu"),
        icon = Icons.Default.TireRepair
    ) {
        FormSectionHeader(DL.t("Araç Bilgileri", "Vehicle Information", "Información del vehículo", "Informations du véhicule"), Icons.Default.DirectionsCar)
        VehiclePicker(catalog.vehicles, selectedImei) { selectedImei = it }

        FormSectionHeader(DL.t("Lastik Bilgileri", "Tire Information", "Información del neumático", "Informations du pneu"), Icons.Default.TireRepair)
        DropdownField(DL.t("Pozisyon", "Position", "Posición", "Position"), position, tirePositions) { position = it }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField(DL.t("Marka", "Brand", "Marca", "Marque"), brand, { brand = it }, modifier = Modifier.weight(1f))
            FormTextField(DL.t("Model", "Model", "Modelo", "Modèle"), model, { model = it }, modifier = Modifier.weight(1f))
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField(DL.t("Ebat", "Size", "Medida", "Dimension"), size, { size = it }, modifier = Modifier.weight(1f), placeholder = "205/55R16")
            FormTextField(DL.t("DOT Kodu", "DOT Code", "Código DOT", "Code DOT"), dotCode, { dotCode = it }, modifier = Modifier.weight(1f))
        }

        FormSectionHeader(DL.t("Kilometre ve Tarih", "Mileage & Date", "Kilometraje y fecha", "Kilométrage et date"), Icons.Default.Speed)
        FormTextField(DL.t("Montaj Tarihi", "Installation Date", "Fecha de instalación", "Date de montage"), installDate, { installDate = it }, placeholder = "2025-01-15")
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            FormTextField(DL.t("Montaj KM", "Install KM", "KM de instalación", "KM montage"), kmAtInstall, { kmAtInstall = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
            FormTextField(DL.t("KM Limiti", "KM Limit", "Límite KM", "Limite KM"), kmLimit, { kmLimit = it }, modifier = Modifier.weight(1f), keyboardType = KeyboardType.Number)
        }
        DropdownField(DL.t("Durum", "Status", "Estado", "Statut"), status, listOf(
            "active" to DL.t("Aktif", "Active", "Activo", "Actif"),
            "worn" to DL.t("Aşınmış", "Worn", "Desgastado", "Usé"),
            "replaced" to DL.t("Değiştirildi", "Replaced", "Reemplazado", "Remplacé"),
            "critical" to DL.t("Kritik", "Critical", "Crítico", "Critique")
        )) { status = it }

        FormSectionHeader(DL.t("Notlar", "Notes", "Notas", "Notes"), Icons.Default.Notes)
        FormTextField(DL.t("Notlar", "Notes", "Notas", "Notes"), notes, { notes = it }, maxLines = 3)

        if (error != null) {
            Text(error!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(top = 8.dp))
        }

        Spacer(Modifier.height(16.dp))
        SaveButton(isEditing = isEditing, isSaving = isSaving) {
            if (selectedImei.isBlank()) {
                error = DL.t("Araç seçimi zorunludur", "Vehicle selection is required", "La selección del vehículo es obligatoria", "La sélection du véhicule est requise"); return@SaveButton
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
                    error = e.localizedMessage ?: DL.t("Kayıt başarısız", "Save failed", "Error al guardar", "Échec de l'enregistrement")
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
            Text(title, fontSize = 17.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface)
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
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
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
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
        Spacer(Modifier.height(4.dp))
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = {
                if (placeholder.isNotEmpty()) Text(placeholder, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f))
            },
            modifier = Modifier.fillMaxWidth(),
            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface),
            singleLine = maxLines == 1,
            maxLines = maxLines,
            shape = RoundedCornerShape(10.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = AppColors.Indigo,
                unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                cursorColor = AppColors.Indigo,
                focusedContainerColor = MaterialTheme.colorScheme.surface,
                unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    var expanded by remember { mutableStateOf(false) }
    val displayText = options.find { it.first == selectedValue }?.second ?: selectedValue.ifEmpty { DL.t("Seçiniz", "Select", "Seleccione", "Sélectionner") }

    Column(modifier = modifier.padding(bottom = 8.dp)) {
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
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
                textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface),
                singleLine = true,
                shape = RoundedCornerShape(10.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = AppColors.Indigo,
                    unfocusedBorderColor = MaterialTheme.colorScheme.outline,
                    focusedContainerColor = MaterialTheme.colorScheme.surface,
                    unfocusedContainerColor = MaterialTheme.colorScheme.surfaceVariant
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    var expanded by remember { mutableStateOf(false) }
    var vehicleSearch by remember { mutableStateOf("") }
    val selectedPlate = vehicles.find { it.imei == selectedImei }?.plate ?: ""
    val filteredVehicles = if (vehicleSearch.isBlank()) vehicles
    else vehicles.filter {
        it.plate.contains(vehicleSearch, ignoreCase = true) || it.name.contains(vehicleSearch, ignoreCase = true)
    }

    Column(modifier = Modifier.padding(bottom = 8.dp)) {
        Text(DL.t("Araç Seçimi", "Vehicle Selection", "Selección de vehículo", "Sélection du véhicule"), fontSize = 12.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f))
        Spacer(Modifier.height(4.dp))
        Box {
            OutlinedTextField(
                value = selectedPlate.ifEmpty { DL.t("Araç seçiniz...", "Select a vehicle...", "Seleccione un vehículo...", "Sélectionnez un véhicule...") },
                onValueChange = {},
                readOnly = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = true },
                textStyle = androidx.compose.ui.text.TextStyle(
                    fontSize = 13.sp,
                    color = if (selectedPlate.isNotEmpty()) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)
                ),
                singleLine = true,
                enabled = false,
                shape = RoundedCornerShape(10.dp),
                leadingIcon = { Icon(Icons.Default.DirectionsCar, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp)) },
                colors = OutlinedTextFieldDefaults.colors(
                    disabledBorderColor = MaterialTheme.colorScheme.outline,
                    disabledTextColor = if (selectedPlate.isNotEmpty()) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f),
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
                    placeholder = { Text(DL.t("Plaka ara...", "Search plate...", "Buscar matrícula...", "Rechercher une plaque..."), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.35f)) },
                    leadingIcon = { Icon(Icons.Default.Search, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                        .height(40.dp),
                    textStyle = androidx.compose.ui.text.TextStyle(fontSize = 12.sp),
                    singleLine = true,
                    shape = RoundedCornerShape(8.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = AppColors.Indigo,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outline
                    )
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outline)
                filteredVehicles.forEach { v ->
                    DropdownMenuItem(
                        text = {
                            Column {
                                Text(v.plate, fontSize = 13.sp, fontWeight = FontWeight.Medium, color = MaterialTheme.colorScheme.onSurface)
                                if (v.name.isNotEmpty()) {
                                    Text(v.name, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f))
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
                                tint = if (v.imei == selectedImei) AppColors.Indigo else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                            )
                        }
                    )
                }
                if (filteredVehicles.isEmpty()) {
                    Text(
                        DL.t("Araç bulunamadı", "No vehicle found", "No se encontró vehículo", "Aucun véhicule trouvé"),
                        modifier = Modifier.padding(16.dp),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
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
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
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
            if (isSaving) DL.t("Kaydediliyor...", "Saving...", "Guardando...", "Enregistrement...")
            else if (isEditing) DL.t("Güncelle", "Update", "Actualizar", "Mettre à jour")
            else DL.t("Kaydet", "Save", "Guardar", "Enregistrer"),
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
        Text(message, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), textAlign = TextAlign.Center)
    }
}

@Composable
private fun ErrorView(message: String, onRetry: () -> Unit) {
    val currentLang by DashboardStrings.currentLang.collectAsState()
    val DL = DashboardStrings
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 80.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(Icons.Default.ErrorOutline, null, tint = Color(0xFFEF4444), modifier = Modifier.size(40.dp))
        Spacer(Modifier.height(12.dp))
        Text(message, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f), textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = onRetry, shape = RoundedCornerShape(8.dp)) {
            Icon(Icons.Default.Refresh, null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(6.dp))
            Text(DL.t("Tekrar Dene", "Try Again", "Intentar de nuevo", "Réessayer"), fontSize = 13.sp)
        }
    }
}
