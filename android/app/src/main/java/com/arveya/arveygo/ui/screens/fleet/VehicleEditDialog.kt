package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.models.Vehicle
import com.arveya.arveygo.services.APIService
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VehicleEditDialog(
    vehicle: Vehicle,
    onDismiss: () -> Unit,
    onSaved: () -> Unit
) {
    var plate by remember { mutableStateOf(vehicle.plate) }
    var name by remember { mutableStateOf(vehicle.name) }
    var brand by remember { mutableStateOf(vehicle.vehicleBrand) }
    var model by remember { mutableStateOf(vehicle.vehicleModel) }
    var year by remember { mutableStateOf("") }
    var vehicleType by remember { mutableStateOf(vehicle.vehicleCategory) }
    var odometer by remember { mutableStateOf(if (vehicle.odometer > 0) vehicle.odometer.toLong().toString() else "") }

    var isSaving by remember { mutableStateOf(false) }
    var errorMsg by remember { mutableStateOf<String?>(null) }
    var showSuccess by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()

    // Vehicle type options
    val vehicleTypes = listOf(
        "car" to "Otomobil",
        "motorcycle" to "Motosiklet",
        "truck" to "Kamyon",
        "van" to "Minibüs / Van",
        "bus" to "Otobüs"
    )
    var typeExpanded by remember { mutableStateOf(false) }
    val selectedTypeLabel = vehicleTypes.firstOrNull { it.first == vehicleType }?.second ?: vehicleType

    if (showSuccess) {
        AlertDialog(
            onDismissRequest = { onSaved() },
            icon = {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(52.dp)
                        .background(Color(0xFF22C55E).copy(alpha = 0.12f), RoundedCornerShape(50))
                ) {
                    Icon(Icons.Default.Check, null, tint = Color(0xFF22C55E), modifier = Modifier.size(26.dp))
                }
            },
            title = { Text("Başarılı", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface) },
            text = { Text("Araç bilgileri başarıyla güncellendi.", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) },
            confirmButton = {
                Button(
                    onClick = { onSaved() },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF22C55E)),
                    shape = RoundedCornerShape(10.dp)
                ) { Text("Tamam", fontWeight = FontWeight.SemiBold) }
            },
            shape = RoundedCornerShape(16.dp)
        )
        return
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(16.dp),
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color(0xFF8B5CF6).copy(alpha = 0.12f), RoundedCornerShape(10.dp))
                ) {
                    Icon(Icons.Default.Edit, null, tint = Color(0xFF8B5CF6), modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(10.dp))
                Column {
                    Text("Araç Düzenle", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = MaterialTheme.colorScheme.onSurface)
                    Text(vehicle.plate, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 420.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Plate
                OutlinedTextField(
                    value = plate,
                    onValueChange = { plate = it.uppercase() },
                    label = { Text("Plaka", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Default.DirectionsCar, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF8B5CF6),
                        focusedLabelColor = Color(0xFF8B5CF6)
                    )
                )

                // Name
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Araç Adı / Takma Ad", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Default.Label, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF8B5CF6),
                        focusedLabelColor = Color(0xFF8B5CF6)
                    )
                )

                // Brand
                OutlinedTextField(
                    value = brand,
                    onValueChange = { brand = it },
                    label = { Text("Marka", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Default.CarRental, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF8B5CF6),
                        focusedLabelColor = Color(0xFF8B5CF6)
                    )
                )

                // Model
                OutlinedTextField(
                    value = model,
                    onValueChange = { model = it },
                    label = { Text("Model", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Default.Info, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF8B5CF6),
                        focusedLabelColor = Color(0xFF8B5CF6)
                    )
                )

                // Year
                OutlinedTextField(
                    value = year,
                    onValueChange = { year = it.filter { c -> c.isDigit() }.take(4) },
                    label = { Text("Model Yılı", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Default.CalendarToday, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF8B5CF6),
                        focusedLabelColor = Color(0xFF8B5CF6)
                    )
                )

                // Vehicle Type Dropdown
                ExposedDropdownMenuBox(
                    expanded = typeExpanded,
                    onExpandedChange = { typeExpanded = !typeExpanded }
                ) {
                    OutlinedTextField(
                        value = selectedTypeLabel,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Araç Tipi", fontSize = 12.sp) },
                        leadingIcon = { Icon(Icons.Default.Category, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = typeExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Color(0xFF8B5CF6),
                            focusedLabelColor = Color(0xFF8B5CF6)
                        )
                    )
                    ExposedDropdownMenu(
                        expanded = typeExpanded,
                        onDismissRequest = { typeExpanded = false }
                    ) {
                        vehicleTypes.forEach { (key, label) ->
                            DropdownMenuItem(
                                text = { Text(label, fontSize = 13.sp) },
                                onClick = {
                                    vehicleType = key
                                    typeExpanded = false
                                },
                                leadingIcon = {
                                    if (vehicleType == key) Icon(Icons.Default.Check, null, tint = Color(0xFF8B5CF6), modifier = Modifier.size(14.dp))
                                }
                            )
                        }
                    }
                }

                // Odometer
                OutlinedTextField(
                    value = odometer,
                    onValueChange = { odometer = it.filter { c -> c.isDigit() } },
                    label = { Text("Kilometre (Odometer)", fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Default.Speed, null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary) },
                    suffix = { Text("km", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color(0xFF8B5CF6),
                        focusedLabelColor = Color(0xFF8B5CF6)
                    )
                )

                // Error
                if (errorMsg != null) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color.Red.copy(alpha = 0.08f), RoundedCornerShape(8.dp))
                            .padding(10.dp)
                    ) {
                        Icon(Icons.Default.ErrorOutline, null, tint = Color.Red, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(errorMsg!!, fontSize = 12.sp, color = Color.Red)
                    }
                }

                if (isSaving) {
                    LinearProgressIndicator(
                        modifier = Modifier.fillMaxWidth(),
                        color = Color(0xFF8B5CF6)
                    )
                }
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (plate.isBlank()) { errorMsg = "Plaka alanı zorunludur."; return@Button }
                    isSaving = true
                    errorMsg = null
                    scope.launch {
                        try {
                            val body = mutableMapOf<String, Any>("plate" to plate)
                            if (name.isNotBlank()) body["name"] = name
                            if (brand.isNotBlank()) body["brand"] = brand
                            if (model.isNotBlank()) body["model"] = model
                            if (year.isNotBlank()) body["year"] = year.toIntOrNull() ?: 0
                            if (vehicleType.isNotBlank()) body["vehicle_type"] = vehicleType
                            if (odometer.isNotBlank()) body["odometer"] = odometer.toLongOrNull() ?: 0L
                            APIService.updateVehicle(vehicle.deviceId, body)
                            isSaving = false
                            showSuccess = true
                        } catch (e: Exception) {
                            isSaving = false
                            errorMsg = e.message ?: "Güncelleme başarısız."
                        }
                    }
                },
                enabled = !isSaving,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8B5CF6)),
                shape = RoundedCornerShape(10.dp)
            ) {
                if (isSaving) {
                    CircularProgressIndicator(color = Color.White, modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                } else {
                    Icon(Icons.Default.Check, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text("Kaydet", fontWeight = FontWeight.SemiBold)
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !isSaving) {
                Text("İptal", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    )
}
