package com.arveya.arveygo.ui.screens.support

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.text.KeyboardOptions
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.theme.AppColors

/**
 * Support Request page — shown when WebSocket connection fails repeatedly.
 * Modeled after web's integration request form.
 */

private enum class SupportCategory(
    val label: String,
    val icon: ImageVector
) {
    CONNECTION("Bağlantı", Icons.Default.WifiOff),
    DEVICE("Cihaz", Icons.Default.Memory),
    SOFTWARE("Yazılım", Icons.Default.Laptop),
    BILLING("Fatura", Icons.Default.CreditCard),
    INTEGRATION("Entegrasyon", Icons.Default.Sync),
    OTHER("Diğer", Icons.Default.MoreHoriz)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportRequestScreen(onBack: () -> Unit) {
    var selectedCategory by remember { mutableStateOf(SupportCategory.CONNECTION) }
    var subject by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var contactEmail by remember { mutableStateOf("") }
    var contactPhone by remember { mutableStateOf("") }
    var showSuccessDialog by remember { mutableStateOf(false) }

    if (showSuccessDialog) {
        AlertDialog(
            onDismissRequest = { showSuccessDialog = false; onBack() },
            title = { Text("Talebiniz Alındı", fontWeight = FontWeight.Bold, color = AppColors.Navy) },
            text = { Text("Destek ekibimiz en kısa sürede sizinle iletişime geçecektir. Ortalama yanıt süresi 24-48 saattir.", color = AppColors.TextMuted) },
            confirmButton = {
                TextButton(onClick = { showSuccessDialog = false; onBack() }) {
                    Text("Tamam", fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                }
            }
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.ChevronLeft, null, tint = AppColors.Navy, modifier = Modifier.size(18.dp))
                            Text("Geri", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        }
                    }
                },
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Text("Destek Talebi", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        Text("Arveya Teknoloji", fontSize = 10.sp, color = AppColors.TextMuted)
                    }
                },
                actions = { Spacer(Modifier.width(48.dp)) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .background(AppColors.Bg)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // Warning card
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.Surface, RoundedCornerShape(16.dp))
                    .border(1.dp, Color.Red.copy(alpha = 0.2f), RoundedCornerShape(16.dp))
                    .padding(24.dp)
            ) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(Color.Red.copy(alpha = 0.1f))
                ) {
                    Icon(Icons.Default.Warning, null, tint = Color.Red, modifier = Modifier.size(24.dp))
                }
                Spacer(Modifier.height(12.dp))
                Text("Bağlantı Sorunu", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
                Spacer(Modifier.height(8.dp))
                Text(
                    "Sunucuya bağlantı kurulamadı. Lütfen internet bağlantınızı kontrol edin veya aşağıdaki formu doldurarak destek ekibimize ulaşın.",
                    fontSize = 13.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center, lineHeight = 18.sp
                )
                Spacer(Modifier.height(14.dp))

                // Retry button
                OutlinedButton(
                    onClick = {
                        WebSocketManager.reconnect()
                        onBack()
                    },
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = AppColors.Indigo),
                    border = BorderStroke(1.dp, AppColors.Indigo.copy(alpha = 0.3f))
                ) {
                    Icon(Icons.Default.Refresh, null, modifier = Modifier.size(14.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Tekrar Dene", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            // Category picker
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("DESTEK KATEGORİSİ", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 0.5.sp)

                // 3 columns x 2 rows
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (i in SupportCategory.entries.indices step 3) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            for (j in 0 until 3) {
                                val idx = i + j
                                if (idx < SupportCategory.entries.size) {
                                    val cat = SupportCategory.entries[idx]
                                    val isSelected = selectedCategory == cat
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier = Modifier
                                            .weight(1f)
                                            .background(
                                                if (isSelected) AppColors.Indigo.copy(alpha = 0.08f) else AppColors.Surface,
                                                RoundedCornerShape(12.dp)
                                            )
                                            .border(
                                                if (isSelected) 1.5.dp else 1.dp,
                                                if (isSelected) AppColors.Indigo else AppColors.BorderSoft,
                                                RoundedCornerShape(12.dp)
                                            )
                                            .clickable { selectedCategory = cat }
                                            .padding(vertical = 14.dp)
                                    ) {
                                        Icon(cat.icon, null, tint = if (isSelected) AppColors.Navy else AppColors.TextMuted, modifier = Modifier.size(16.dp))
                                        Spacer(Modifier.height(6.dp))
                                        Text(cat.label, fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = if (isSelected) AppColors.Navy else AppColors.TextMuted)
                                    }
                                } else {
                                    Spacer(Modifier.weight(1f))
                                }
                            }
                        }
                    }
                }
            }

            // Form
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("TALEP DETAYLARI", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 0.5.sp)

                // Subject
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("Konu", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                    OutlinedTextField(
                        value = subject,
                        onValueChange = { subject = it },
                        placeholder = { Text("Örn: Soket bağlantısı kurulamıyor", fontSize = 13.sp) },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            unfocusedBorderColor = AppColors.BorderSoft,
                            focusedBorderColor = AppColors.Navy,
                            unfocusedContainerColor = AppColors.Surface,
                            focusedContainerColor = AppColors.Surface
                        ),
                        singleLine = true,
                        textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp)
                    )
                }

                // Description
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("Detaylı Açıklama", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                    OutlinedTextField(
                        value = description,
                        onValueChange = { description = it },
                        placeholder = { Text("Sorununuzu detaylıca açıklayınız...", fontSize = 13.sp) },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 100.dp),
                        shape = RoundedCornerShape(10.dp),
                        colors = OutlinedTextFieldDefaults.colors(
                            unfocusedBorderColor = AppColors.BorderSoft,
                            focusedBorderColor = AppColors.Navy,
                            unfocusedContainerColor = AppColors.Surface,
                            focusedContainerColor = AppColors.Surface
                        ),
                        maxLines = 5,
                        textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp)
                    )
                }

                // Email + Phone row
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.weight(1f)) {
                        Text("E-Posta", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        OutlinedTextField(
                            value = contactEmail,
                            onValueChange = { contactEmail = it },
                            placeholder = { Text("ornek@email.com", fontSize = 13.sp) },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                unfocusedBorderColor = AppColors.BorderSoft,
                                focusedBorderColor = AppColors.Navy,
                                unfocusedContainerColor = AppColors.Surface,
                                focusedContainerColor = AppColors.Surface
                            ),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp)
                        )
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.weight(1f)) {
                        Text("Telefon", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                        OutlinedTextField(
                            value = contactPhone,
                            onValueChange = { contactPhone = it },
                            placeholder = { Text("+90 5XX", fontSize = 13.sp) },
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(10.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                unfocusedBorderColor = AppColors.BorderSoft,
                                focusedBorderColor = AppColors.Navy,
                                unfocusedContainerColor = AppColors.Surface,
                                focusedContainerColor = AppColors.Surface
                            ),
                            singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 13.sp)
                        )
                    }
                }
            }

            // Submit button
            val isValid = subject.isNotBlank() && description.isNotBlank() && contactEmail.isNotBlank()
            Button(
                onClick = { if (isValid) showSuccessDialog = true },
                enabled = isValid,
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = AppColors.Navy,
                    disabledContainerColor = AppColors.TextMuted
                ),
                modifier = Modifier.fillMaxWidth().height(50.dp)
            ) {
                Icon(Icons.Default.Send, null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(8.dp))
                Text("Talebi Gönder", fontSize = 15.sp, fontWeight = FontWeight.Bold)
            }

            Spacer(Modifier.height(20.dp))
        }
    }
}
