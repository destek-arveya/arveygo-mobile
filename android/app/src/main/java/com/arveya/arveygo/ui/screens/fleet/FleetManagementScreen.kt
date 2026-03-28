package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.LocalAuthViewModel
import com.arveya.arveygo.models.*
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.components.AvatarCircle
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private enum class FleetTab(val label: String) {
    MAINTENANCE("Bakım"),
    COSTS("Masraflar"),
    DOCUMENTS("Belgeler")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FleetManagementScreen(onMenuClick: () -> Unit) {
    val user = LocalAuthViewModel.current.currentUser.collectAsState().value
    var selectedTab by remember { mutableStateOf(FleetTab.MAINTENANCE) }

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

    // CRUD states
    var showMaintenanceSheet by remember { mutableStateOf(false) }
    var editingMaintenance by remember { mutableStateOf<FleetMaintenance?>(null) }
    var showCostSheet by remember { mutableStateOf(false) }
    var editingCost by remember { mutableStateOf<VehicleCost?>(null) }
    var showDocumentSheet by remember { mutableStateOf(false) }
    var editingDocument by remember { mutableStateOf<FleetDocument?>(null) }
    var deleteTarget by remember { mutableStateOf<Any?>(null) }
    var deleteType by remember { mutableStateOf("") }

    val scope = rememberCoroutineScope()

    fun loadData() {
        scope.launch {
            isLoading = true; errorMessage = null
            try {
                catalog = APIService.fetchFleetCatalog()
                reminders = try { APIService.fetchFleetReminders(60) } catch (_: Exception) { emptyList() }
                val (mL, mP) = APIService.fetchFleetMaintenance(); maintenanceList = mL; maintenancePagination = mP
                val (cL, cP) = APIService.fetchFleetCosts(); costsList = cL; costsPagination = cP
                val (dL, dP) = APIService.fetchFleetDocuments(); documentsList = dL; documentsPagination = dP
            } catch (e: Exception) { errorMessage = e.message }
            isLoading = false
        }
    }

    LaunchedEffect(Unit) { loadData() }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onMenuClick) {
                        Icon(Icons.Default.Menu, null, tint = AppColors.Navy, modifier = Modifier.size(22.dp))
                    }
                },
                title = {
                    Column {
                        Text("Bakım / Belgeler / Masraflar", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("Filo Yönetimi", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = {
                    IconButton(onClick = { loadData() }) {
                        Icon(Icons.Default.Refresh, "Yenile", tint = AppColors.TextMuted, modifier = Modifier.size(20.dp))
                    }
                    IconButton(onClick = {
                        when (selectedTab) {
                            FleetTab.MAINTENANCE -> { editingMaintenance = null; showMaintenanceSheet = true }
                            FleetTab.COSTS -> { editingCost = null; showCostSheet = true }
                            FleetTab.DOCUMENTS -> { editingDocument = null; showDocumentSheet = true }
                        }
                    }) {
                        Icon(Icons.Default.AddCircle, "Ekle", tint = AppColors.Indigo, modifier = Modifier.size(22.dp))
                    }
                    AvatarCircle(initials = user?.avatar ?: "A", size = 30.dp)
                    Spacer(Modifier.width(8.dp))
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        },
        containerColor = AppColors.Bg
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (reminders.isNotEmpty()) RemindersBanner(reminders)
            FleetTabSelector(selectedTab) { selectedTab = it }

            if (isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = AppColors.Indigo, strokeWidth = 2.dp, modifier = Modifier.size(32.dp))
                }
            } else if (errorMessage != null) {
                ErrorView(errorMessage!!) { loadData() }
            } else {
                when (selectedTab) {
                    FleetTab.MAINTENANCE -> MaintenanceListTab(maintenanceList, maintenancePagination,
                        onPageChange = { p -> scope.launch { try { val (l, pg) = APIService.fetchFleetMaintenance(page = p); maintenanceList = maintenanceList + l; maintenancePagination = pg } catch (_: Exception) {} } },
                        onEdit = { editingMaintenance = it; showMaintenanceSheet = true },
                        onDelete = { deleteTarget = it; deleteType = "maintenance" })
                    FleetTab.COSTS -> CostsListTab(costsList, costsPagination,
                        onPageChange = { p -> scope.launch { try { val (l, pg) = APIService.fetchFleetCosts(page = p); costsList = costsList + l; costsPagination = pg } catch (_: Exception) {} } },
                        onEdit = { editingCost = it; showCostSheet = true },
                        onDelete = { deleteTarget = it; deleteType = "cost" })
                    FleetTab.DOCUMENTS -> DocumentsListTab(documentsList, documentsPagination,
                        onPageChange = { p -> scope.launch { try { val (l, pg) = APIService.fetchFleetDocuments(page = p); documentsList = documentsList + l; documentsPagination = pg } catch (_: Exception) {} } },
                        onEdit = { editingDocument = it; showDocumentSheet = true },
                        onDelete = { deleteTarget = it; deleteType = "document" })
                }
            }
        }
    }

    // Delete confirmation
    if (deleteTarget != null) {
        AlertDialog(
            onDismissRequest = { deleteTarget = null },
            title = { Text("Silme Onayı") },
            text = { Text("Bu kaydı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.") },
            confirmButton = {
                TextButton(onClick = {
                    val t = deleteTarget; scope.launch {
                        try {
                            when (deleteType) {
                                "maintenance" -> { val i = t as FleetMaintenance; APIService.deleteFleetMaintenance(i.id.toInt()); maintenanceList = maintenanceList.filter { it.id != i.id } }
                                "cost" -> { val i = t as VehicleCost; APIService.deleteFleetCost(i.id.toInt()); costsList = costsList.filter { it.id != i.id } }
                                "document" -> { val i = t as FleetDocument; APIService.deleteFleetDocument(i.id.toInt()); documentsList = documentsList.filter { it.id != i.id } }
                            }
                        } catch (_: Exception) {}
                        deleteTarget = null
                    }
                }) { Text("Sil", color = Color.Red, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { deleteTarget = null }) { Text("İptal", color = AppColors.TextMuted) } }
        )
    }

    if (showMaintenanceSheet) MaintenanceFormSheet(catalog, editingMaintenance, { showMaintenanceSheet = false }, { loadData(); showMaintenanceSheet = false })
    if (showCostSheet) CostFormSheet(catalog, editingCost, { showCostSheet = false }, { loadData(); showCostSheet = false })
    if (showDocumentSheet) DocumentFormSheet(catalog, editingDocument, { showDocumentSheet = false }, { loadData(); showDocumentSheet = false })
}

// ═══════════════════════════════════════════════════════════
// MARK: - Form Sheets
// ═══════════════════════════════════════════════════════════

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MaintenanceFormSheet(catalog: FleetCatalog?, editing: FleetMaintenance?, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val isEdit = editing != null; val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }; var errorMsg by remember { mutableStateOf<String?>(null) }
    var selectedImei by remember { mutableStateOf(editing?.imei ?: "") }
    var maintenanceType by remember { mutableStateOf(editing?.maintenanceType ?: "") }
    var serviceDate by remember { mutableStateOf(editing?.serviceDate ?: todayStr()) }
    var nextServiceDate by remember { mutableStateOf(editing?.nextServiceDate ?: "") }
    var kmAtService by remember { mutableStateOf(editing?.kmAtService?.toString() ?: "") }
    var nextServiceKm by remember { mutableStateOf(editing?.nextServiceKm?.toString() ?: "") }
    var cost by remember { mutableStateOf(editing?.cost?.let { String.format(Locale("tr"), "%.0f", it) } ?: "") }
    var workshop by remember { mutableStateOf(editing?.workshop ?: "") }
    var description by remember { mutableStateOf(editing?.description ?: "") }
    var status by remember { mutableStateOf(editing?.status ?: "done") }

    val types = listOf("periodic" to "Periyodik Bakım", "oil_change" to "Yağ Değişimi", "tire_change" to "Lastik Değişimi", "brake_service" to "Fren Bakımı", "filter_change" to "Filtre Değişimi", "battery" to "Akü Kontrolü", "other" to "Diğer")
    val statuses = listOf("done" to "Tamamlandı", "scheduled" to "Planlandı", "overdue" to "Gecikmiş")

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Color.White, dragHandle = { BottomSheetDefaults.DragHandle() }) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text(if (isEdit) "Bakım Kaydını Düzenle" else "Yeni Bakım Kaydı", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
            Spacer(Modifier.height(16.dp))
            FormLabel("Araç *"); VehiclePicker(catalog, selectedImei) { selectedImei = it }; Spacer(Modifier.height(12.dp))
            FormLabel("Bakım Türü *"); DropdownField(types, maintenanceType) { maintenanceType = it }; Spacer(Modifier.height(12.dp))
            FormLabel("Servis Tarihi *"); FormTextField(serviceDate, { serviceDate = it }, "2026-03-28"); Spacer(Modifier.height(12.dp))
            FormLabel("Sonraki Servis Tarihi"); FormTextField(nextServiceDate, { nextServiceDate = it }, "2026-06-28"); Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f)) { FormLabel("Servis KM"); FormTextField(kmAtService, { kmAtService = it }, "45000", KeyboardType.Number) }
                Column(Modifier.weight(1f)) { FormLabel("Sonraki KM"); FormTextField(nextServiceKm, { nextServiceKm = it }, "55000", KeyboardType.Number) }
            }; Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f)) { FormLabel("Tutar (₺)"); FormTextField(cost, { cost = it }, "1500", KeyboardType.Decimal) }
                Column(Modifier.weight(1f)) { FormLabel("Atölye"); FormTextField(workshop, { workshop = it }, "Oto Servis") }
            }; Spacer(Modifier.height(12.dp))
            FormLabel("Durum"); DropdownField(statuses, status) { status = it }; Spacer(Modifier.height(12.dp))
            FormLabel("Açıklama"); FormTextField(description, { description = it }, "Opsiyonel açıklama...", singleLine = false); Spacer(Modifier.height(16.dp))
            if (errorMsg != null) Text(errorMsg!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(bottom = 8.dp))
            SaveButton(isEdit, isSaving) {
                if (selectedImei.isBlank() || maintenanceType.isBlank() || serviceDate.isBlank()) { errorMsg = "Araç, bakım türü ve servis tarihi zorunludur."; return@SaveButton }
                isSaving = true; errorMsg = null; scope.launch {
                    try {
                        val body = mutableMapOf<String, Any>("device_imei" to selectedImei, "maintenance_type" to maintenanceType, "service_date" to serviceDate, "status" to status)
                        if (nextServiceDate.isNotBlank()) body["next_service_date"] = nextServiceDate
                        if (kmAtService.isNotBlank()) body["km_at_service"] = kmAtService.toIntOrNull() ?: 0
                        if (nextServiceKm.isNotBlank()) body["next_service_km"] = nextServiceKm.toIntOrNull() ?: 0
                        if (cost.isNotBlank()) body["cost"] = cost.replace(",", ".").toDoubleOrNull() ?: 0.0
                        if (workshop.isNotBlank()) body["workshop"] = workshop
                        if (description.isNotBlank()) body["description"] = description
                        if (isEdit) APIService.updateFleetMaintenance(editing!!.id.toInt(), body) else APIService.createFleetMaintenance(body)
                        onSaved()
                    } catch (e: Exception) { errorMsg = e.message ?: "Hata oluştu" }
                    isSaving = false
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CostFormSheet(catalog: FleetCatalog?, editing: VehicleCost?, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val isEdit = editing != null; val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }; var errorMsg by remember { mutableStateOf<String?>(null) }
    var selectedImei by remember { mutableStateOf(editing?.imei ?: "") }
    var category by remember { mutableStateOf(editing?.category ?: "") }
    var amount by remember { mutableStateOf(if (editing != null && editing.amount > 0) String.format(Locale("tr"), "%.0f", editing.amount) else "") }
    var costDate by remember { mutableStateOf(editing?.costDate ?: todayStr()) }
    var description by remember { mutableStateOf(editing?.description ?: "") }
    var referenceNo by remember { mutableStateOf(editing?.referenceNo ?: "") }

    val categories = listOf("fuel" to "Yakıt", "maintenance" to "Bakım", "tire" to "Lastik", "insurance" to "Sigorta", "tax" to "Vergi", "fine" to "Ceza", "other" to "Diğer")

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Color.White, dragHandle = { BottomSheetDefaults.DragHandle() }) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text(if (isEdit) "Masraf Kaydını Düzenle" else "Yeni Masraf Kaydı", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
            Spacer(Modifier.height(16.dp))
            FormLabel("Araç *"); VehiclePicker(catalog, selectedImei) { selectedImei = it }; Spacer(Modifier.height(12.dp))
            FormLabel("Kategori *"); DropdownField(categories, category) { category = it }; Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f)) { FormLabel("Tutar (₺) *"); FormTextField(amount, { amount = it }, "2500", KeyboardType.Decimal) }
                Column(Modifier.weight(1f)) { FormLabel("Tarih *"); FormTextField(costDate, { costDate = it }, "2026-03-28") }
            }; Spacer(Modifier.height(12.dp))
            FormLabel("Referans No"); FormTextField(referenceNo, { referenceNo = it }, "Fatura no, fiş no vb."); Spacer(Modifier.height(12.dp))
            FormLabel("Açıklama"); FormTextField(description, { description = it }, "Opsiyonel açıklama...", singleLine = false); Spacer(Modifier.height(16.dp))
            if (errorMsg != null) Text(errorMsg!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(bottom = 8.dp))
            SaveButton(isEdit, isSaving) {
                if (selectedImei.isBlank() || category.isBlank() || amount.isBlank() || costDate.isBlank()) { errorMsg = "Araç, kategori, tutar ve tarih zorunludur."; return@SaveButton }
                isSaving = true; errorMsg = null; scope.launch {
                    try {
                        val body = mutableMapOf<String, Any>("device_imei" to selectedImei, "category" to category, "amount" to (amount.replace(",", ".").toDoubleOrNull() ?: 0.0), "cost_date" to costDate)
                        if (description.isNotBlank()) body["description"] = description
                        if (referenceNo.isNotBlank()) body["reference_no"] = referenceNo
                        if (isEdit) APIService.updateFleetCost(editing!!.id.toInt(), body) else APIService.createFleetCost(body)
                        onSaved()
                    } catch (e: Exception) { errorMsg = e.message ?: "Hata oluştu" }
                    isSaving = false
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DocumentFormSheet(catalog: FleetCatalog?, editing: FleetDocument?, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val isEdit = editing != null; val scope = rememberCoroutineScope()
    var isSaving by remember { mutableStateOf(false) }; var errorMsg by remember { mutableStateOf<String?>(null) }
    var selectedImei by remember { mutableStateOf(editing?.imei ?: "") }
    var docType by remember { mutableStateOf(editing?.docType ?: "") }
    var title by remember { mutableStateOf(editing?.title ?: "") }
    var issueDate by remember { mutableStateOf(editing?.issueDate ?: "") }
    var expiryDate by remember { mutableStateOf(editing?.expiryDate ?: "") }
    var reminderDays by remember { mutableStateOf(editing?.reminderDays?.toString() ?: "30") }
    var notes by remember { mutableStateOf(editing?.notes ?: "") }

    val docTypes = listOf("ruhsat" to "Ruhsat", "sigorta" to "Sigorta", "muayene" to "Muayene", "egzoz" to "Egzoz", "fenni_muayene" to "Fenni Muayene", "other" to "Diğer")

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Color.White, dragHandle = { BottomSheetDefaults.DragHandle() }) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 32.dp)) {
            Text(if (isEdit) "Belge Kaydını Düzenle" else "Yeni Belge Kaydı", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
            Spacer(Modifier.height(16.dp))
            FormLabel("Araç *"); VehiclePicker(catalog, selectedImei) { selectedImei = it }; Spacer(Modifier.height(12.dp))
            FormLabel("Belge Türü *"); DropdownField(docTypes, docType) { docType = it }; Spacer(Modifier.height(12.dp))
            FormLabel("Başlık *"); FormTextField(title, { title = it }, "Belge adı"); Spacer(Modifier.height(12.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Column(Modifier.weight(1f)) { FormLabel("Düzenleme Tarihi"); FormTextField(issueDate, { issueDate = it }, "2026-01-01") }
                Column(Modifier.weight(1f)) { FormLabel("Bitiş Tarihi"); FormTextField(expiryDate, { expiryDate = it }, "2027-01-01") }
            }; Spacer(Modifier.height(12.dp))
            FormLabel("Hatırlatma (gün)"); FormTextField(reminderDays, { reminderDays = it }, "30", KeyboardType.Number); Spacer(Modifier.height(12.dp))
            FormLabel("Notlar"); FormTextField(notes, { notes = it }, "Opsiyonel notlar...", singleLine = false); Spacer(Modifier.height(16.dp))
            if (errorMsg != null) Text(errorMsg!!, fontSize = 12.sp, color = Color.Red, modifier = Modifier.padding(bottom = 8.dp))
            SaveButton(isEdit, isSaving) {
                if (selectedImei.isBlank() || docType.isBlank() || title.isBlank()) { errorMsg = "Araç, belge türü ve başlık zorunludur."; return@SaveButton }
                isSaving = true; errorMsg = null; scope.launch {
                    try {
                        val body = mutableMapOf<String, Any>("device_imei" to selectedImei, "doc_type" to docType, "title" to title)
                        if (issueDate.isNotBlank()) body["issue_date"] = issueDate
                        if (expiryDate.isNotBlank()) body["expiry_date"] = expiryDate
                        if (reminderDays.isNotBlank()) body["reminder_days"] = reminderDays.toIntOrNull() ?: 30
                        if (notes.isNotBlank()) body["notes"] = notes
                        if (isEdit) APIService.updateFleetDocument(editing!!.id.toInt(), body) else APIService.createFleetDocument(body)
                        onSaved()
                    } catch (e: Exception) { errorMsg = e.message ?: "Hata oluştu" }
                    isSaving = false
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Shared Form Components
// ═══════════════════════════════════════════════════════════

@Composable
private fun FormLabel(text: String) {
    Text(text, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy, modifier = Modifier.padding(bottom = 4.dp))
}

@Composable
private fun FormTextField(value: String, onValueChange: (String) -> Unit, placeholder: String = "", keyboardType: KeyboardType = KeyboardType.Text, singleLine: Boolean = true) {
    OutlinedTextField(
        value = value, onValueChange = onValueChange,
        placeholder = { Text(placeholder, fontSize = 13.sp, color = AppColors.TextFaint) },
        singleLine = singleLine, keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier.fillMaxWidth(),
        textStyle = LocalTextStyle.current.copy(fontSize = 13.sp, color = AppColors.Navy),
        shape = RoundedCornerShape(8.dp),
        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Indigo, unfocusedBorderColor = AppColors.BorderSoft, cursorColor = AppColors.Indigo)
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DropdownField(options: List<Pair<String, String>>, selected: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val label = options.find { it.first == selected }?.second ?: "Seçiniz"
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(value = label, onValueChange = {}, readOnly = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier.menuAnchor().fillMaxWidth(),
            textStyle = LocalTextStyle.current.copy(fontSize = 13.sp, color = AppColors.Navy),
            shape = RoundedCornerShape(8.dp),
            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Indigo, unfocusedBorderColor = AppColors.BorderSoft))
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (key, lbl) -> DropdownMenuItem(text = { Text(lbl, fontSize = 13.sp) }, onClick = { onSelect(key); expanded = false }) }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VehiclePicker(catalog: FleetCatalog?, selectedImei: String, onSelect: (String) -> Unit) {
    val vehicles = catalog?.vehicles ?: emptyList()
    var expanded by remember { mutableStateOf(false) }
    val sel = vehicles.find { it.imei == selectedImei }
    val displayText = sel?.let { "${it.plate} (${it.name})" } ?: if (selectedImei.isNotBlank()) selectedImei else "Araç seçiniz"
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(value = displayText, onValueChange = {}, readOnly = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier.menuAnchor().fillMaxWidth(),
            textStyle = LocalTextStyle.current.copy(fontSize = 13.sp, color = AppColors.Navy),
            shape = RoundedCornerShape(8.dp),
            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = AppColors.Indigo, unfocusedBorderColor = AppColors.BorderSoft))
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            vehicles.forEach { v ->
                DropdownMenuItem(text = {
                    Column { Text(v.plate, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy); if (v.name.isNotEmpty()) Text(v.name, fontSize = 11.sp, color = AppColors.TextMuted) }
                }, onClick = { onSelect(v.imei); expanded = false })
            }
        }
    }
}

@Composable
private fun SaveButton(isEdit: Boolean, isSaving: Boolean, onClick: () -> Unit) {
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth().height(48.dp), enabled = !isSaving,
        colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo), shape = RoundedCornerShape(10.dp)) {
        if (isSaving) CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
        else Text(if (isEdit) "Güncelle" else "Kaydet", fontWeight = FontWeight.SemiBold)
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Reminders / Tabs
// ═══════════════════════════════════════════════════════════

@Composable
private fun RemindersBanner(reminders: List<FleetReminder>) {
    val urgent = reminders.filter { it.daysLeft <= 7 }; val upcoming = reminders.filter { it.daysLeft in 8..30 }
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        if (urgent.isNotEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().background(Color.Red.copy(alpha = 0.08f), RoundedCornerShape(10.dp)).padding(12.dp)) {
                Icon(Icons.Default.Warning, null, tint = Color.Red, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp))
                Text("${urgent.size} acil hatırlatma (7 gün içinde)", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.Red)
            }; Spacer(Modifier.height(6.dp))
        }
        if (upcoming.isNotEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().background(Color(0xFFFF9800).copy(alpha = 0.08f), RoundedCornerShape(10.dp)).padding(12.dp)) {
                Icon(Icons.Default.Schedule, null, tint = Color(0xFFFF9800), modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp))
                Text("${upcoming.size} yaklaşan hatırlatma (30 gün içinde)", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFFFF9800))
            }
        }
    }
}

@Composable
private fun FleetTabSelector(selected: FleetTab, onSelect: (FleetTab) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).background(AppColors.Navy.copy(alpha = 0.04f), RoundedCornerShape(10.dp)).padding(4.dp)) {
        FleetTab.entries.forEach { tab ->
            val isActive = tab == selected
            Box(contentAlignment = Alignment.Center, modifier = Modifier.weight(1f).clip(RoundedCornerShape(8.dp)).background(if (isActive) Color.White else Color.Transparent).clickable { onSelect(tab) }.padding(vertical = 10.dp)) {
                Text(tab.label, fontSize = 13.sp, fontWeight = if (isActive) FontWeight.Bold else FontWeight.Medium, color = if (isActive) AppColors.Indigo else AppColors.TextMuted)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - List Tabs
// ═══════════════════════════════════════════════════════════

@Composable
private fun MaintenanceListTab(items: List<FleetMaintenance>, pagination: PaginationMeta, onPageChange: (Int) -> Unit, onEdit: (FleetMaintenance) -> Unit, onDelete: (FleetMaintenance) -> Unit) {
    if (items.isEmpty()) EmptyStateView(Icons.Default.Build, "Bakım Kaydı Yok", "Henüz bakım kaydı bulunmamaktadır.\nYeni kayıt eklemek için + butonuna dokunun.")
    else LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { Text("Toplam ${pagination.total} kayıt", fontSize = 11.sp, color = AppColors.TextMuted, modifier = Modifier.padding(bottom = 4.dp)) }
        items(items, key = { it.id }) { item -> MaintenanceCard(item, { onEdit(item) }, { onDelete(item) }) }
        if (pagination.hasMore) item { TextButton(onClick = { onPageChange(pagination.currentPage + 1) }, Modifier.fillMaxWidth()) { Text("Daha fazla yükle", color = AppColors.Indigo) } }
        item { Spacer(Modifier.height(16.dp)) }
    }
}

@Composable
private fun MaintenanceCard(item: FleetMaintenance, onEdit: () -> Unit, onDelete: () -> Unit) {
    Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp)).border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp)).clickable { onEdit() }.padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(contentAlignment = Alignment.Center, modifier = Modifier.size(36.dp).clip(CircleShape).background(item.statusColor.copy(alpha = 0.1f))) {
                Icon(Icons.Default.Build, null, tint = item.statusColor, modifier = Modifier.size(16.dp))
            }; Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(item.maintenanceType.ifEmpty { "Bakım" }, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                Text(item.plate, fontSize = 12.sp, color = AppColors.TextMuted)
            }
            Text(item.statusLabel, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = item.statusColor, modifier = Modifier.background(item.statusColor.copy(alpha = 0.1f), RoundedCornerShape(20.dp)).padding(horizontal = 8.dp, vertical = 4.dp))
        }
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            if (item.serviceDate != null) InfoChip(Icons.Default.CalendarToday, "Servis: ${item.serviceDate}")
            if (item.nextServiceDate != null) InfoChip(Icons.Default.Event, "Sonraki: ${item.nextServiceDate}")
            if (item.kmAtService != null) InfoChip(Icons.Default.Speed, "${NumberFormat.getNumberInstance(Locale("tr", "TR")).format(item.kmAtService)} km")
        }
        if (item.workshop.isNotEmpty()) { Spacer(Modifier.height(4.dp)); Text("Atölye: ${item.workshop}", fontSize = 11.sp, color = AppColors.TextMuted) }
        if (item.cost != null && item.cost > 0) { Spacer(Modifier.height(4.dp)); Text("Tutar: ${item.formattedCost}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy) }
        Spacer(Modifier.height(6.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            TextButton(onClick = onEdit, contentPadding = PaddingValues(horizontal = 8.dp)) { Icon(Icons.Default.Edit, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp)); Spacer(Modifier.width(4.dp)); Text("Düzenle", fontSize = 11.sp, color = AppColors.Indigo) }
            TextButton(onClick = onDelete, contentPadding = PaddingValues(horizontal = 8.dp)) { Icon(Icons.Default.Delete, null, tint = Color.Red.copy(alpha = 0.7f), modifier = Modifier.size(14.dp)); Spacer(Modifier.width(4.dp)); Text("Sil", fontSize = 11.sp, color = Color.Red.copy(alpha = 0.7f)) }
        }
    }
}

@Composable
private fun CostsListTab(items: List<VehicleCost>, pagination: PaginationMeta, onPageChange: (Int) -> Unit, onEdit: (VehicleCost) -> Unit, onDelete: (VehicleCost) -> Unit) {
    if (items.isEmpty()) EmptyStateView(Icons.Default.AttachMoney, "Masraf Kaydı Yok", "Henüz masraf kaydı bulunmamaktadır.\nYeni kayıt eklemek için + butonuna dokunun.")
    else {
        val total = items.sumOf { it.amount }; val byCat = items.groupBy { it.category }.mapValues { (_, v) -> v.sumOf { it.amount } }
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { CostSummaryCard(total, byCat) }
            item { Text("Toplam ${pagination.total} kayıt", fontSize = 11.sp, color = AppColors.TextMuted, modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)) }
            items(items, key = { it.id }) { cost -> CostCard(cost, { onEdit(cost) }, { onDelete(cost) }) }
            if (pagination.hasMore) item { TextButton(onClick = { onPageChange(pagination.currentPage + 1) }, Modifier.fillMaxWidth()) { Text("Daha fazla yükle", color = AppColors.Indigo) } }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun CostSummaryCard(total: Double, byCategory: Map<String, Double>) {
    val fmt = NumberFormat.getNumberInstance(Locale("tr", "TR")).apply { maximumFractionDigits = 0 }
    Column(Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp)).border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp)).padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Default.BarChart, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp)); Spacer(Modifier.width(6.dp)); Text("MASRAF ÖZETİ", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 0.5.sp) }
        Spacer(Modifier.height(12.dp))
        if (byCategory.isNotEmpty()) { Row(Modifier.fillMaxWidth()) { byCategory.entries.take(4).forEach { (cat, amt) -> Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.weight(1f)) { Text("₺${fmt.format(amt)}", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy); Text(categoryLabel(cat), fontSize = 9.sp, color = AppColors.TextMuted) } } }; Spacer(Modifier.height(10.dp)) }
        Row(horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().background(AppColors.Navy.copy(alpha = 0.04f), RoundedCornerShape(10.dp)).padding(12.dp)) {
            Text("TOPLAM", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted); Text("₺${fmt.format(total)}", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
        }
    }
}

@Composable
private fun CostCard(cost: VehicleCost, onEdit: () -> Unit, onDelete: () -> Unit) {
    val color = categoryColor(cost.category); val icon = categoryIcon(cost.category)
    Row(verticalAlignment = Alignment.Top, modifier = Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp)).border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp)).clickable { onEdit() }.padding(14.dp)) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(36.dp).background(color.copy(alpha = 0.1f), RoundedCornerShape(8.dp))) { Icon(icon, null, tint = color, modifier = Modifier.size(16.dp)) }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(categoryLabel(cost.category), fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text("${cost.plate} • ${cost.costDate}", fontSize = 11.sp, color = AppColors.TextMuted)
            if (cost.description.isNotEmpty()) Text(cost.description, fontSize = 10.sp, color = AppColors.TextFaint, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(Modifier.padding(top = 4.dp)) {
                TextButton(onClick = onEdit, contentPadding = PaddingValues(horizontal = 4.dp), modifier = Modifier.height(24.dp)) { Icon(Icons.Default.Edit, null, tint = AppColors.Indigo, modifier = Modifier.size(12.dp)); Spacer(Modifier.width(2.dp)); Text("Düzenle", fontSize = 10.sp, color = AppColors.Indigo) }
                TextButton(onClick = onDelete, contentPadding = PaddingValues(horizontal = 4.dp), modifier = Modifier.height(24.dp)) { Icon(Icons.Default.Delete, null, tint = Color.Red.copy(alpha = 0.7f), modifier = Modifier.size(12.dp)); Spacer(Modifier.width(2.dp)); Text("Sil", fontSize = 10.sp, color = Color.Red.copy(alpha = 0.7f)) }
            }
        }
        Text(cost.formattedAmount, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
    }
}

@Composable
private fun DocumentsListTab(items: List<FleetDocument>, pagination: PaginationMeta, onPageChange: (Int) -> Unit, onEdit: (FleetDocument) -> Unit, onDelete: (FleetDocument) -> Unit) {
    if (items.isEmpty()) EmptyStateView(Icons.Default.Description, "Belge Kaydı Yok", "Henüz belge kaydı bulunmamaktadır.\nYeni kayıt eklemek için + butonuna dokunun.")
    else LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item { Text("Toplam ${pagination.total} kayıt", fontSize = 11.sp, color = AppColors.TextMuted, modifier = Modifier.padding(bottom = 4.dp)) }
        items(items, key = { it.id }) { doc -> DocumentCard(doc, { onEdit(doc) }, { onDelete(doc) }) }
        if (pagination.hasMore) item { TextButton(onClick = { onPageChange(pagination.currentPage + 1) }, Modifier.fillMaxWidth()) { Text("Daha fazla yükle", color = AppColors.Indigo) } }
        item { Spacer(Modifier.height(16.dp)) }
    }
}

@Composable
private fun DocumentCard(doc: FleetDocument, onEdit: () -> Unit, onDelete: () -> Unit) {
    Row(verticalAlignment = Alignment.Top, modifier = Modifier.fillMaxWidth().background(Color.White, RoundedCornerShape(12.dp)).border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp)).clickable { onEdit() }.padding(14.dp)) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(36.dp).clip(CircleShape).background(doc.statusColor.copy(alpha = 0.1f))) { Icon(Icons.Default.Description, null, tint = doc.statusColor, modifier = Modifier.size(16.dp)) }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(doc.title.ifEmpty { doc.docTypeLabel }, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
            Text("${doc.plate} • ${doc.docTypeLabel}", fontSize = 11.sp, color = AppColors.TextMuted)
            if (doc.expiryDate != null) Text("Bitiş: ${doc.expiryDate}", fontSize = 10.sp, color = AppColors.TextFaint)
            Row(Modifier.padding(top = 4.dp)) {
                TextButton(onClick = onEdit, contentPadding = PaddingValues(horizontal = 4.dp), modifier = Modifier.height(24.dp)) { Icon(Icons.Default.Edit, null, tint = AppColors.Indigo, modifier = Modifier.size(12.dp)); Spacer(Modifier.width(2.dp)); Text("Düzenle", fontSize = 10.sp, color = AppColors.Indigo) }
                TextButton(onClick = onDelete, contentPadding = PaddingValues(horizontal = 4.dp), modifier = Modifier.height(24.dp)) { Icon(Icons.Default.Delete, null, tint = Color.Red.copy(alpha = 0.7f), modifier = Modifier.size(12.dp)); Spacer(Modifier.width(2.dp)); Text("Sil", fontSize = 10.sp, color = Color.Red.copy(alpha = 0.7f)) }
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            if (doc.daysLeft != null) { Text("${doc.daysLeft} gün", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = doc.statusColor); Text("kalan", fontSize = 9.sp, color = AppColors.TextMuted) }
            Text(doc.statusLabel, fontSize = 9.sp, fontWeight = FontWeight.SemiBold, color = doc.statusColor, modifier = Modifier.padding(top = 2.dp).background(doc.statusColor.copy(alpha = 0.1f), RoundedCornerShape(20.dp)).padding(horizontal = 6.dp, vertical = 2.dp))
        }
    }
}

// ═══════════════════════════════════════════════════════════
// MARK: - Shared Views & Helpers
// ═══════════════════════════════════════════════════════════

@Composable private fun InfoChip(icon: ImageVector, text: String) { Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.background(AppColors.Bg, RoundedCornerShape(6.dp)).padding(horizontal = 6.dp, vertical = 3.dp)) { Icon(icon, null, tint = AppColors.TextMuted, modifier = Modifier.size(10.dp)); Spacer(Modifier.width(4.dp)); Text(text, fontSize = 10.sp, color = AppColors.TextMuted) } }

@Composable private fun EmptyStateView(icon: ImageVector, title: String, subtitle: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center, modifier = Modifier.fillMaxSize().padding(32.dp)) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(64.dp).background(AppColors.Indigo.copy(alpha = 0.08f), CircleShape)) { Icon(icon, null, tint = AppColors.Indigo.copy(alpha = 0.5f), modifier = Modifier.size(28.dp)) }
        Spacer(Modifier.height(16.dp)); Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
        Spacer(Modifier.height(6.dp)); Text(subtitle, fontSize = 13.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center)
    }
}

@Composable private fun ErrorView(message: String, onRetry: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center, modifier = Modifier.fillMaxSize().padding(32.dp)) {
        Icon(Icons.Default.ErrorOutline, null, tint = Color.Red, modifier = Modifier.size(40.dp)); Spacer(Modifier.height(12.dp))
        Text("Veri yüklenirken hata oluştu", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy); Spacer(Modifier.height(4.dp))
        Text(message, fontSize = 12.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center); Spacer(Modifier.height(16.dp))
        TextButton(onClick = onRetry) { Text("Tekrar Dene", color = AppColors.Indigo, fontWeight = FontWeight.SemiBold) }
    }
}

private fun todayStr(): String = SimpleDateFormat("yyyy-MM-dd", Locale("tr")).format(Date())
private fun categoryColor(c: String): Color = when (c.lowercase()) { "fuel" -> Color(0xFFFF9800); "maintenance" -> Color.Blue; "tire" -> Color(0xFF607D8B); "insurance" -> Color(0xFF9C27B0); "tax" -> Color(0xFF009688); "fine" -> Color.Red; else -> Color(0xFF94A3B8) }
private fun categoryIcon(c: String): ImageVector = when (c.lowercase()) { "fuel" -> Icons.Default.LocalGasStation; "maintenance" -> Icons.Default.Build; "tire" -> Icons.Default.Circle; "insurance" -> Icons.Default.Shield; "tax" -> Icons.Default.AccountBalance; "fine" -> Icons.Default.Warning; else -> Icons.Default.MoreHoriz }
private fun categoryLabel(c: String): String = when (c.lowercase()) { "fuel" -> "Yakıt"; "maintenance" -> "Bakım"; "tire" -> "Lastik"; "insurance" -> "Sigorta"; "tax" -> "Vergi"; "fine" -> "Ceza"; "other" -> "Diğer"; else -> c.replaceFirstChar { it.uppercase() } }
