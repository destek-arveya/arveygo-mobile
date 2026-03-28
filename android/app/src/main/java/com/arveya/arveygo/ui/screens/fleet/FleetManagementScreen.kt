package com.arveya.arveygo.ui.screens.fleet

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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.util.Locale

private enum class FleetTab(val label: String) {
    MAINTENANCE("Bakım"),
    COSTS("Masraflar"),
    DOCUMENTS("Belgeler")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FleetManagementScreen(onMenuClick: () -> Unit) {
    var selectedTab by remember { mutableStateOf(FleetTab.MAINTENANCE) }

    // Data states
    var maintenanceList by remember { mutableStateOf<List<FleetMaintenance>>(emptyList()) }
    var costsList by remember { mutableStateOf<List<VehicleCost>>(emptyList()) }
    var documentsList by remember { mutableStateOf<List<FleetDocument>>(emptyList()) }
    var reminders by remember { mutableStateOf<List<FleetReminder>>(emptyList()) }
    var catalog by remember { mutableStateOf<FleetCatalog?>(null) }

    var maintenancePagination by remember { mutableStateOf(PaginationMeta()) }
    var costsPagination by remember { mutableStateOf(PaginationMeta()) }
    var documentsPagination by remember { mutableStateOf(PaginationMeta()) }

    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()

    // Load data
    fun loadData() {
        scope.launch {
            isLoading = true
            errorMessage = null
            try {
                // Load catalog first
                catalog = APIService.fetchFleetCatalog()

                // Load reminders
                reminders = try { APIService.fetchFleetReminders(60) } catch (_: Exception) { emptyList() }

                // Load all three lists
                val (mList, mPag) = APIService.fetchFleetMaintenance()
                maintenanceList = mList
                maintenancePagination = mPag

                val (cList, cPag) = APIService.fetchFleetCosts()
                costsList = cList
                costsPagination = cPag

                val (dList, dPag) = APIService.fetchFleetDocuments()
                documentsList = dList
                documentsPagination = dPag
            } catch (e: Exception) {
                errorMessage = e.message
            }
            isLoading = false
        }
    }

    LaunchedEffect(Unit) { loadData() }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, "Menü", tint = AppColors.Navy)
                    }
                },
                title = {
                    Column {
                        Text("Filo Yönetimi", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                        if (catalog != null) {
                            Text(
                                "${catalog!!.vehicles.size} araç",
                                fontSize = 11.sp, color = AppColors.TextMuted
                            )
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { loadData() }) {
                        Icon(Icons.Default.Refresh, "Yenile", tint = AppColors.Indigo)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(AppColors.Bg)
                .padding(padding)
        ) {
            // Reminders banner
            if (reminders.isNotEmpty()) {
                RemindersBanner(reminders)
            }

            // Tab selector
            FleetTabSelector(selectedTab) { selectedTab = it }

            // Content
            if (isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 2.dp, modifier = Modifier.size(32.dp))
                }
            } else if (errorMessage != null) {
                ErrorView(errorMessage!!) { loadData() }
            } else {
                when (selectedTab) {
                    FleetTab.MAINTENANCE -> MaintenanceListTab(maintenanceList, maintenancePagination) { page ->
                        scope.launch {
                            try {
                                val (mList, mPag) = APIService.fetchFleetMaintenance(page = page)
                                maintenanceList = mList
                                maintenancePagination = mPag
                            } catch (_: Exception) {}
                        }
                    }
                    FleetTab.COSTS -> CostsListTab(costsList, costsPagination, catalog?.costCategories ?: emptyList()) { page ->
                        scope.launch {
                            try {
                                val (cList, cPag) = APIService.fetchFleetCosts(page = page)
                                costsList = cList
                                costsPagination = cPag
                            } catch (_: Exception) {}
                        }
                    }
                    FleetTab.DOCUMENTS -> DocumentsListTab(documentsList, documentsPagination) { page ->
                        scope.launch {
                            try {
                                val (dList, dPag) = APIService.fetchFleetDocuments(page = page)
                                documentsList = dList
                                documentsPagination = dPag
                            } catch (_: Exception) {}
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Reminders Banner
@Composable
private fun RemindersBanner(reminders: List<FleetReminder>) {
    val urgent = reminders.filter { it.daysLeft <= 7 }
    val upcoming = reminders.filter { it.daysLeft in 8..30 }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        if (urgent.isNotEmpty()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.Red.copy(alpha = 0.08f), RoundedCornerShape(10.dp))
                    .padding(12.dp)
            ) {
                Icon(Icons.Default.Warning, null, tint = Color.Red, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(
                    "${urgent.size} acil hatırlatma (7 gün içinde)",
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.Red
                )
            }
            Spacer(Modifier.height(6.dp))
        }
        if (upcoming.isNotEmpty()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xFFFF9800).copy(alpha = 0.08f), RoundedCornerShape(10.dp))
                    .padding(12.dp)
            ) {
                Icon(Icons.Default.Schedule, null, tint = Color(0xFFFF9800), modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(
                    "${upcoming.size} yaklaşan hatırlatma (30 gün içinde)",
                    fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFFFF9800)
                )
            }
        }
    }
}

// MARK: - Tab Selector
@Composable
private fun FleetTabSelector(selected: FleetTab, onSelect: (FleetTab) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .background(AppColors.Navy.copy(alpha = 0.04f), RoundedCornerShape(10.dp))
            .padding(4.dp)
    ) {
        FleetTab.entries.forEach { tab ->
            val isActive = tab == selected
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (isActive) Color.White else Color.Transparent)
                    .clickable { onSelect(tab) }
                    .padding(vertical = 10.dp)
            ) {
                Text(
                    tab.label,
                    fontSize = 13.sp,
                    fontWeight = if (isActive) FontWeight.Bold else FontWeight.Medium,
                    color = if (isActive) AppColors.Indigo else AppColors.TextMuted
                )
            }
        }
    }
}

// MARK: - Maintenance List Tab
@Composable
private fun MaintenanceListTab(
    items: List<FleetMaintenance>,
    pagination: PaginationMeta,
    onPageChange: (Int) -> Unit
) {
    if (items.isEmpty()) {
        EmptyStateView(Icons.Default.Build, "Bakım Kaydı Yok", "Henüz bakım kaydı bulunmamaktadır.")
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item {
                Text(
                    "Toplam ${pagination.total} kayıt",
                    fontSize = 11.sp, color = AppColors.TextMuted,
                    modifier = Modifier.padding(bottom = 4.dp)
                )
            }
            items(items, key = { it.id }) { item ->
                MaintenanceCard(item)
            }
            if (pagination.hasMore) {
                item {
                    TextButton(
                        onClick = { onPageChange(pagination.currentPage + 1) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Daha fazla yükle", color = AppColors.Indigo)
                    }
                }
            }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun MaintenanceCard(item: FleetMaintenance) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(12.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(item.statusColor.copy(alpha = 0.1f))
            ) {
                Icon(Icons.Default.Build, null, tint = item.statusColor, modifier = Modifier.size(16.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(item.maintenanceType.ifEmpty { "Bakım" }, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                Text(item.plate, fontSize = 12.sp, color = AppColors.TextMuted)
            }
            Text(
                item.statusLabel,
                fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = item.statusColor,
                modifier = Modifier
                    .background(item.statusColor.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            )
        }
        Spacer(Modifier.height(10.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            if (item.serviceDate != null) {
                InfoChip(Icons.Default.CalendarToday, "Servis: ${item.serviceDate}")
            }
            if (item.nextServiceDate != null) {
                InfoChip(Icons.Default.Event, "Sonraki: ${item.nextServiceDate}")
            }
            if (item.kmAtService != null) {
                val fmt = NumberFormat.getNumberInstance(Locale("tr", "TR"))
                InfoChip(Icons.Default.Speed, "${fmt.format(item.kmAtService)} km")
            }
        }
        if (item.workshop.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            Text("Atölye: ${item.workshop}", fontSize = 11.sp, color = AppColors.TextMuted)
        }
        if (item.cost != null && item.cost > 0) {
            Spacer(Modifier.height(4.dp))
            Text("Tutar: ${item.formattedCost}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }
    }
}

// MARK: - Costs List Tab
@Composable
private fun CostsListTab(
    items: List<VehicleCost>,
    pagination: PaginationMeta,
    categories: List<String>,
    onPageChange: (Int) -> Unit
) {
    if (items.isEmpty()) {
        EmptyStateView(Icons.Default.AttachMoney, "Masraf Kaydı Yok", "Henüz masraf kaydı bulunmamaktadır.")
    } else {
        // Calculate summary
        val totalAmount = items.sumOf { it.amount }
        val byCat = items.groupBy { it.category }.mapValues { (_, v) -> v.sumOf { it.amount } }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Summary card
            item {
                CostSummaryCard(totalAmount, byCat)
            }

            item {
                Text(
                    "Toplam ${pagination.total} kayıt",
                    fontSize = 11.sp, color = AppColors.TextMuted,
                    modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)
                )
            }

            items(items, key = { it.id }) { cost ->
                CostCard(cost)
            }

            if (pagination.hasMore) {
                item {
                    TextButton(
                        onClick = { onPageChange(pagination.currentPage + 1) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Daha fazla yükle", color = AppColors.Indigo)
                    }
                }
            }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun CostSummaryCard(total: Double, byCategory: Map<String, Double>) {
    val fmt = NumberFormat.getNumberInstance(Locale("tr", "TR")).apply { maximumFractionDigits = 0 }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(12.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.BarChart, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(6.dp))
            Text("MASRAF ÖZETİ", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 0.5.sp)
        }
        Spacer(Modifier.height(12.dp))

        if (byCategory.isNotEmpty()) {
            Row(modifier = Modifier.fillMaxWidth()) {
                byCategory.entries.take(4).forEach { (cat, amount) ->
                    val color = categoryColor(cat)
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("₺${fmt.format(amount)}", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                        Text(categoryLabel(cat), fontSize = 9.sp, color = AppColors.TextMuted)
                    }
                }
            }
            Spacer(Modifier.height(10.dp))
        }

        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.Navy.copy(alpha = 0.04f), RoundedCornerShape(10.dp))
                .padding(12.dp)
        ) {
            Text("TOPLAM", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted)
            Text("₺${fmt.format(total)}", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }
    }
}

@Composable
private fun CostCard(cost: VehicleCost) {
    val color = categoryColor(cost.category)
    val icon = categoryIcon(cost.category)

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(12.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            .padding(14.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(36.dp)
                .background(color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(16.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(categoryLabel(cost.category), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text("${cost.plate} • ${cost.costDate}", fontSize = 11.sp, color = AppColors.TextMuted)
            if (cost.description.isNotEmpty()) {
                Text(cost.description, fontSize = 10.sp, color = AppColors.TextFaint, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Text(cost.formattedAmount, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
    }
}

// MARK: - Documents List Tab
@Composable
private fun DocumentsListTab(
    items: List<FleetDocument>,
    pagination: PaginationMeta,
    onPageChange: (Int) -> Unit
) {
    if (items.isEmpty()) {
        EmptyStateView(Icons.Default.Description, "Belge Kaydı Yok", "Henüz belge kaydı bulunmamaktadır.")
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item {
                Text(
                    "Toplam ${pagination.total} kayıt",
                    fontSize = 11.sp, color = AppColors.TextMuted,
                    modifier = Modifier.padding(bottom = 4.dp)
                )
            }
            items(items, key = { it.id }) { doc ->
                DocumentCard(doc)
            }
            if (pagination.hasMore) {
                item {
                    TextButton(
                        onClick = { onPageChange(pagination.currentPage + 1) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Daha fazla yükle", color = AppColors.Indigo)
                    }
                }
            }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun DocumentCard(doc: FleetDocument) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White, RoundedCornerShape(12.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            .padding(14.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(doc.statusColor.copy(alpha = 0.1f))
        ) {
            Icon(Icons.Default.Description, null, tint = doc.statusColor, modifier = Modifier.size(16.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(doc.title.ifEmpty { doc.docTypeLabel }, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text("${doc.plate} • ${doc.docTypeLabel}", fontSize = 11.sp, color = AppColors.TextMuted)
            if (doc.expiryDate != null) {
                Text("Bitiş: ${doc.expiryDate}", fontSize = 10.sp, color = AppColors.TextFaint)
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            if (doc.daysLeft != null) {
                Text(
                    "${doc.daysLeft} gün",
                    fontSize = 13.sp, fontWeight = FontWeight.Bold, color = doc.statusColor
                )
                Text("kalan", fontSize = 9.sp, color = AppColors.TextMuted)
            }
            Text(
                doc.statusLabel,
                fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = doc.statusColor,
                modifier = Modifier
                    .padding(top = 2.dp)
                    .background(doc.statusColor.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            )
        }
    }
}

// MARK: - Shared Components

@Composable
private fun InfoChip(icon: ImageVector, text: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(AppColors.Bg, RoundedCornerShape(6.dp))
            .padding(horizontal = 6.dp, vertical = 3.dp)
    ) {
        Icon(icon, null, tint = AppColors.TextMuted, modifier = Modifier.size(10.dp))
        Spacer(Modifier.width(4.dp))
        Text(text, fontSize = 10.sp, color = AppColors.TextMuted)
    }
}

@Composable
private fun EmptyStateView(icon: ImageVector, title: String, subtitle: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(64.dp)
                .background(AppColors.Indigo.copy(alpha = 0.08f), CircleShape)
        ) {
            Icon(icon, null, tint = AppColors.Indigo.copy(alpha = 0.5f), modifier = Modifier.size(28.dp))
        }
        Spacer(Modifier.height(16.dp))
        Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
        Spacer(Modifier.height(6.dp))
        Text(subtitle, fontSize = 13.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center)
    }
}

@Composable
private fun ErrorView(message: String, onRetry: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp)
    ) {
        Icon(Icons.Default.ErrorOutline, null, tint = Color.Red, modifier = Modifier.size(40.dp))
        Spacer(Modifier.height(12.dp))
        Text("Veri yüklenirken hata oluştu", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
        Spacer(Modifier.height(4.dp))
        Text(message, fontSize = 12.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center)
        Spacer(Modifier.height(16.dp))
        TextButton(onClick = onRetry) {
            Text("Tekrar Dene", color = AppColors.Indigo, fontWeight = FontWeight.SemiBold)
        }
    }
}

// MARK: - Helpers

private fun categoryColor(category: String): Color = when (category.lowercase()) {
    "fuel" -> Color(0xFFFF9800)
    "maintenance" -> Color.Blue
    "tire" -> Color(0xFF607D8B)
    "insurance" -> Color(0xFF9C27B0)
    "tax" -> Color(0xFF009688)
    "fine" -> Color.Red
    else -> Color(0xFF94A3B8)
}

private fun categoryIcon(category: String): ImageVector = when (category.lowercase()) {
    "fuel" -> Icons.Default.LocalGasStation
    "maintenance" -> Icons.Default.Build
    "tire" -> Icons.Default.Circle
    "insurance" -> Icons.Default.Shield
    "tax" -> Icons.Default.AccountBalance
    "fine" -> Icons.Default.Warning
    else -> Icons.Default.MoreHoriz
}

private fun categoryLabel(category: String): String = when (category.lowercase()) {
    "fuel" -> "Yakıt"
    "maintenance" -> "Bakım"
    "tire" -> "Lastik"
    "insurance" -> "Sigorta"
    "tax" -> "Vergi"
    "fine" -> "Ceza"
    "other" -> "Diğer"
    else -> category.replaceFirstChar { it.uppercase() }
}
