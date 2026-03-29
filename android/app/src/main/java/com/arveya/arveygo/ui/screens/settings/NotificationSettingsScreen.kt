package com.arveya.arveygo.ui.screens.settings

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.arveya.arveygo.services.APIService
import com.arveya.arveygo.ui.theme.AppColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationSettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("arveygo_notif_prefs", Context.MODE_PRIVATE) }
    val scope = rememberCoroutineScope()

    // Permission state
    var hasPermission by remember { mutableStateOf(checkNotificationPermission(context)) }

    // Category preferences
    var alarmNotifications by remember { mutableStateOf(prefs.getBoolean("alarm_notifications", true)) }
    var maintenanceNotifications by remember { mutableStateOf(prefs.getBoolean("maintenance_notifications", true)) }
    var geofenceNotifications by remember { mutableStateOf(prefs.getBoolean("geofence_notifications", true)) }
    var systemNotifications by remember { mutableStateOf(prefs.getBoolean("system_notifications", true)) }

    // Quiet hours
    var quietHoursEnabled by remember { mutableStateOf(prefs.getBoolean("quiet_hours_enabled", false)) }
    var quietStart by remember { mutableStateOf(prefs.getString("quiet_hours_start", "23:00") ?: "23:00") }
    var quietEnd by remember { mutableStateOf(prefs.getString("quiet_hours_end", "07:00") ?: "07:00") }

    // Time picker states
    var showStartPicker by remember { mutableStateOf(false) }
    var showEndPicker by remember { mutableStateOf(false) }

    // Permission launcher (Android 13+)
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasPermission = granted
    }

    // Save function
    fun save() {
        prefs.edit()
            .putBoolean("alarm_notifications", alarmNotifications)
            .putBoolean("maintenance_notifications", maintenanceNotifications)
            .putBoolean("geofence_notifications", geofenceNotifications)
            .putBoolean("system_notifications", systemNotifications)
            .putBoolean("quiet_hours_enabled", quietHoursEnabled)
            .putString("quiet_hours_start", quietStart)
            .putString("quiet_hours_end", quietEnd)
            .apply()

        // Sync to backend
        scope.launch {
            try {
                val json = JSONObject().apply {
                    put("alarm_notifications", alarmNotifications)
                    put("maintenance_notifications", maintenanceNotifications)
                    put("geofence_notifications", geofenceNotifications)
                    put("system_notifications", systemNotifications)
                    put("quiet_hours_enabled", quietHoursEnabled)
                    put("quiet_hours_start", quietStart)
                    put("quiet_hours_end", quietEnd)
                }
                withContext(Dispatchers.IO) {
                    APIService.post("/api/mobile/notification-settings", json)
                }
            } catch (_: Exception) { /* fire & forget */ }
        }
    }

    // Check permission on resume
    LaunchedEffect(Unit) {
        hasPermission = checkNotificationPermission(context)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, null, tint = AppColors.Navy)
                    }
                },
                title = {
                    Text("Bildirim Ayarları", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = AppColors.Surface)
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(AppColors.Bg)
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // ── Push Permission Card ──
            SectionHeader(icon = Icons.Default.NotificationsActive, title = "PUSH BİLDİRİM")

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(
                        1.dp,
                        if (hasPermission) Color(0xFF16A34A).copy(alpha = 0.3f) else AppColors.BorderSoft,
                        RoundedCornerShape(12.dp)
                    )
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                ) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(36.dp)
                            .background(
                                if (hasPermission) Color(0xFF16A34A) else Color(0xFFDC2626),
                                RoundedCornerShape(10.dp)
                            )
                    ) {
                        Icon(
                            if (hasPermission) Icons.Default.NotificationsActive else Icons.Default.NotificationsOff,
                            null, tint = Color.White, modifier = Modifier.size(18.dp)
                        )
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            if (hasPermission) "Bildirimler Açık" else "Bildirimler Kapalı",
                            fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy
                        )
                        Text(
                            if (hasPermission) "Araç alarmları ve hatırlatmalar alabilirsiniz"
                            else "Bildirimleri alabilmek için izin verin",
                            fontSize = 11.sp, color = AppColors.TextMuted
                        )
                    }
                    if (hasPermission) {
                        Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF16A34A), modifier = Modifier.size(22.dp))
                    }
                }

                if (!hasPermission) {
                    HorizontalDivider(modifier = Modifier.padding(start = 60.dp))
                    Button(
                        onClick = {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                            } else {
                                // Open app notification settings
                                val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                                }
                                context.startActivity(intent)
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.Indigo),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Icon(Icons.Default.NotificationsActive, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("İzin Ver", fontWeight = FontWeight.SemiBold)
                    }
                }
            }

            // ── Category Toggles ──
            SectionHeader(icon = Icons.Default.Tune, title = "BİLDİRİM KATEGORİLERİ")

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            ) {
                NotifToggleRow(
                    icon = Icons.Default.Warning,
                    iconColor = Color(0xFFEF4444),
                    title = "Araç Alarmları",
                    subtitle = "Hız, geofence, motor vb.",
                    checked = alarmNotifications,
                    onCheckedChange = { alarmNotifications = it; save() }
                )
                HorizontalDivider(modifier = Modifier.padding(start = 60.dp))

                NotifToggleRow(
                    icon = Icons.Default.Build,
                    iconColor = Color(0xFFF59E0B),
                    title = "Bakım Hatırlatmaları",
                    subtitle = "Servis, muayene, belge tarihleri",
                    checked = maintenanceNotifications,
                    onCheckedChange = { maintenanceNotifications = it; save() }
                )
                HorizontalDivider(modifier = Modifier.padding(start = 60.dp))

                NotifToggleRow(
                    icon = Icons.Default.LocationOn,
                    iconColor = AppColors.Indigo,
                    title = "Geofence Bildirimleri",
                    subtitle = "Bölge giriş/çıkış uyarıları",
                    checked = geofenceNotifications,
                    onCheckedChange = { geofenceNotifications = it; save() }
                )
                HorizontalDivider(modifier = Modifier.padding(start = 60.dp))

                NotifToggleRow(
                    icon = Icons.Default.Campaign,
                    iconColor = Color(0xFF8B5CF6),
                    title = "Sistem Duyuruları",
                    subtitle = "Güncelleme ve bilgilendirmeler",
                    checked = systemNotifications,
                    onCheckedChange = { systemNotifications = it; save() }
                )
            }

            Text(
                "Bu ayarlar sunucu tarafında saklanır. Bildirimleri tamamen kapatmak için yukarıdaki Push izinini kapatın.",
                fontSize = 10.sp, color = AppColors.TextMuted,
                modifier = Modifier.padding(horizontal = 4.dp)
            )

            // ── Quiet Hours ──
            SectionHeader(icon = Icons.Default.DarkMode, title = "SESSİZ SAATLER")

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.Surface, RoundedCornerShape(12.dp))
                    .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(12.dp))
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                ) {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(36.dp)
                            .background(AppColors.Indigo.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
                    ) {
                        Icon(Icons.Default.Bedtime, null, tint = AppColors.Indigo, modifier = Modifier.size(18.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Sessiz Saatler", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
                        Text("Bu saatlerde bildirim gelmez", fontSize = 11.sp, color = AppColors.TextMuted)
                    }
                    Switch(
                        checked = quietHoursEnabled,
                        onCheckedChange = { quietHoursEnabled = it; save() },
                        colors = SwitchDefaults.colors(checkedTrackColor = AppColors.Indigo)
                    )
                }

                if (quietHoursEnabled) {
                    HorizontalDivider(modifier = Modifier.padding(start = 60.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceEvenly,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                    ) {
                        // Start time
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Başlangıç", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted)
                            Spacer(Modifier.height(4.dp))
                            OutlinedButton(
                                onClick = { showStartPicker = true },
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, AppColors.Indigo.copy(alpha = 0.3f))
                            ) {
                                Icon(Icons.Default.Schedule, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(quietStart, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                            }
                        }

                        Icon(Icons.Default.ArrowForward, null, tint = AppColors.TextMuted, modifier = Modifier.size(16.dp))

                        // End time
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Bitiş", fontSize = 11.sp, fontWeight = FontWeight.Medium, color = AppColors.TextMuted)
                            Spacer(Modifier.height(4.dp))
                            OutlinedButton(
                                onClick = { showEndPicker = true },
                                shape = RoundedCornerShape(8.dp),
                                border = BorderStroke(1.dp, AppColors.Indigo.copy(alpha = 0.3f))
                            ) {
                                Icon(Icons.Default.Schedule, null, tint = AppColors.Indigo, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text(quietEnd, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
        }
    }

    // Time Pickers
    if (showStartPicker) {
        TimePickerDialog(
            initialTime = quietStart,
            onDismiss = { showStartPicker = false },
            onConfirm = { time -> quietStart = time; showStartPicker = false; save() }
        )
    }
    if (showEndPicker) {
        TimePickerDialog(
            initialTime = quietEnd,
            onDismiss = { showEndPicker = false },
            onConfirm = { time -> quietEnd = time; showEndPicker = false; save() }
        )
    }
}

@Composable
private fun SectionHeader(icon: ImageVector, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 1.sp)
    }
}

@Composable
private fun NotifToggleRow(
    icon: ImageVector,
    iconColor: Color,
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(36.dp)
                .background(iconColor.copy(alpha = 0.12f), RoundedCornerShape(8.dp))
        ) {
            Icon(icon, null, tint = iconColor, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = AppColors.Navy)
            Text(subtitle, fontSize = 11.sp, color = AppColors.TextMuted)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(checkedTrackColor = AppColors.Indigo)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimePickerDialog(
    initialTime: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    val parts = initialTime.split(":")
    val state = rememberTimePickerState(
        initialHour = parts.getOrNull(0)?.toIntOrNull() ?: 0,
        initialMinute = parts.getOrNull(1)?.toIntOrNull() ?: 0,
        is24Hour = true
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                val time = String.format("%02d:%02d", state.hour, state.minute)
                onConfirm(time)
            }) {
                Text("Tamam", color = AppColors.Indigo)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("İptal", color = AppColors.TextMuted)
            }
        },
        text = {
            TimePicker(
                state = state,
                colors = TimePickerDefaults.colors(
                    selectorColor = AppColors.Indigo,
                    timeSelectorSelectedContainerColor = AppColors.Indigo.copy(alpha = 0.12f),
                    timeSelectorSelectedContentColor = AppColors.Indigo
                )
            )
        }
    )
}

private fun checkNotificationPermission(context: Context): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        ContextCompat.checkSelfPermission(
            context, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    } else {
        // Pre-13: notifications enabled by default
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        manager.areNotificationsEnabled()
    }
}
