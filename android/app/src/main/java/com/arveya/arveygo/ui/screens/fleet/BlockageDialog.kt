package com.arveya.arveygo.ui.screens.fleet

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.models.Vehicle
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.launch

private enum class BlockageAction(
    val label: String,
    val subtitle: String,
    val icon: ImageVector,
    val color: Color,
    val apiAction: String
) {
    BLOCK("Blokaj Uygula", "Aracın motorunu uzaktan durdur", Icons.Default.Lock, Color(0xFFEF4444), "block"),
    UNBLOCK("Blokajı Kaldır", "Aracın motorunu yeniden çalıştır", Icons.Default.LockOpen, Color(0xFF22C55E), "unblock")
}

@Composable
fun BlockageDialog(
    vehicle: Vehicle,
    onDismiss: () -> Unit
) {
    var pendingAction by remember { mutableStateOf<BlockageAction?>(null) }
    var isLoading by remember { mutableStateOf(false) }
    var errorMsg by remember { mutableStateOf<String?>(null) }
    var successMsg by remember { mutableStateOf<String?>(null) }
    var showConfirm by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()

    // Confirm dialog
    if (showConfirm && pendingAction != null) {
        val action = pendingAction!!
        AlertDialog(
            onDismissRequest = { showConfirm = false; pendingAction = null },
            icon = {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(52.dp)
                        .background(action.color.copy(alpha = 0.12f), CircleShape)
                ) {
                    Icon(action.icon, null, tint = action.color, modifier = Modifier.size(26.dp))
                }
            },
            title = {
                Text(
                    "Emin misiniz?",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp,
                    color = AppColors.Navy
                )
            },
            text = {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        "${vehicle.plate} aracı için:",
                        fontSize = 13.sp,
                        color = AppColors.TextMuted,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        action.label,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = action.color,
                        textAlign = TextAlign.Center
                    )
                    Text(
                        "komutu gönderilecek.",
                        fontSize = 13.sp,
                        color = AppColors.TextMuted,
                        textAlign = TextAlign.Center
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showConfirm = false
                        isLoading = true
                        errorMsg = null
                        scope.launch {
                            try {
                                APIService.sendBlockage(vehicle.deviceId, action.apiAction)
                                isLoading = false
                                successMsg = "${action.label} komutu başarıyla gönderildi."
                            } catch (e: Exception) {
                                isLoading = false
                                errorMsg = e.message ?: "Komut gönderilemedi."
                                pendingAction = null
                            }
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = action.color),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("Onayla", fontWeight = FontWeight.SemiBold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirm = false; pendingAction = null }) {
                    Text("İptal", color = AppColors.TextMuted)
                }
            },
            shape = RoundedCornerShape(16.dp)
        )
    }

    // Success dialog
    if (successMsg != null) {
        AlertDialog(
            onDismissRequest = { onDismiss() },
            icon = {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .size(52.dp)
                        .background(Color(0xFF22C55E).copy(alpha = 0.12f), CircleShape)
                ) {
                    Icon(Icons.Default.Check, null, tint = Color(0xFF22C55E), modifier = Modifier.size(26.dp))
                }
            },
            title = { Text("Komut Gönderildi", fontWeight = FontWeight.Bold, color = AppColors.Navy) },
            text = { Text(successMsg!!, fontSize = 14.sp, color = AppColors.TextMuted, textAlign = TextAlign.Center) },
            confirmButton = {
                Button(
                    onClick = { onDismiss() },
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
                        .background(Color(0xFFEF4444).copy(alpha = 0.12f), RoundedCornerShape(10.dp))
                ) {
                    Icon(Icons.Default.Lock, null, tint = Color(0xFFEF4444), modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(10.dp))
                Column {
                    Text("Blokaj", fontWeight = FontWeight.Bold, fontSize = 16.sp, color = AppColors.Navy)
                    Text(vehicle.plate, fontSize = 11.sp, color = AppColors.TextMuted)
                }
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Blockage action cards
                BlockageAction.entries.forEach { action ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .border(1.5.dp, action.color.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                            .background(action.color.copy(alpha = 0.05f))
                            .clickable(enabled = !isLoading) {
                                pendingAction = action
                                showConfirm = true
                            }
                            .padding(14.dp)
                    ) {
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .size(42.dp)
                                .background(action.color.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                        ) {
                            Icon(action.icon, null, tint = action.color, modifier = Modifier.size(20.dp))
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(action.label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                            Text(action.subtitle, fontSize = 11.sp, color = AppColors.TextMuted)
                        }
                        Icon(Icons.Default.ChevronRight, null, tint = action.color.copy(alpha = 0.7f), modifier = Modifier.size(18.dp))
                    }
                }

                HorizontalDivider(color = AppColors.BorderSoft, modifier = Modifier.padding(vertical = 4.dp))

                // Cancel pending command
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(10.dp))
                        .background(AppColors.Bg)
                        .clickable(enabled = !isLoading) {
                            isLoading = true
                            errorMsg = null
                            scope.launch {
                                try {
                                    APIService.cancelBlockage(vehicle.deviceId)
                                    isLoading = false
                                    successMsg = "Bekleyen blokaj komutu iptal edildi."
                                } catch (e: Exception) {
                                    isLoading = false
                                    errorMsg = e.message ?: "İptal işlemi başarısız."
                                }
                            }
                        }
                        .padding(12.dp)
                ) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(36.dp)
                            .background(AppColors.TextMuted.copy(alpha = 0.1f), RoundedCornerShape(10.dp))
                    ) {
                        Icon(Icons.Default.Cancel, null, tint = AppColors.TextMuted, modifier = Modifier.size(16.dp))
                    }
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Bekleyen Komutu İptal Et", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Text("Gönderilmemiş komutları temizle", fontSize = 11.sp, color = AppColors.TextMuted)
                    }
                }

                // Error message
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

                // Loading indicator
                if (isLoading) {
                    LinearProgressIndicator(
                        modifier = Modifier.fillMaxWidth(),
                        color = Color(0xFFEF4444)
                    )
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !isLoading) {
                Text("Kapat", color = AppColors.TextMuted)
            }
        }
    )
}
