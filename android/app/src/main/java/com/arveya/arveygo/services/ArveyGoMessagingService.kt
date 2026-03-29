package com.arveya.arveygo.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.arveya.arveygo.MainActivity
import com.arveya.arveygo.R
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Firebase Cloud Messaging service — handles incoming push notifications
 * and FCM token refresh events.
 *
 * Channels:
 *   - alarm_channel:       Araç alarmları (hız, motor, geofence) — HIGH importance
 *   - maintenance_channel:  Bakım hatırlatmaları — DEFAULT importance
 *   - geofence_channel:    Geofence giriş/çıkış — HIGH importance
 *   - system_channel:      Sistem duyuruları — DEFAULT importance
 */
class ArveyGoMessagingService : FirebaseMessagingService() {

    private val job = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.IO + job)

    companion object {
        private const val TAG = "FCM"

        // Channel IDs
        const val CHANNEL_ALARM = "alarm_channel"
        const val CHANNEL_MAINTENANCE = "maintenance_channel"
        const val CHANNEL_GEOFENCE = "geofence_channel"
        const val CHANNEL_SYSTEM = "system_channel"

        /**
         * Create all notification channels — call from MainActivity.onCreate()
         */
        fun createNotificationChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

            val manager = context.getSystemService(NotificationManager::class.java)

            val channels = listOf(
                NotificationChannel(CHANNEL_ALARM, "Araç Alarmları", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Hız aşımı, motor açma/kapama ve diğer araç alarmları"
                    enableVibration(true)
                    setShowBadge(true)
                },
                NotificationChannel(CHANNEL_MAINTENANCE, "Bakım Hatırlatmaları", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Servis zamanı, muayene tarihi ve belge süreleri"
                    setShowBadge(true)
                },
                NotificationChannel(CHANNEL_GEOFENCE, "Geofence Bildirimleri", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Araç bölge giriş/çıkış bildirimleri"
                    enableVibration(true)
                    setShowBadge(true)
                },
                NotificationChannel(CHANNEL_SYSTEM, "Sistem Duyuruları", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Güncelleme ve genel bilgilendirmeler"
                }
            )

            channels.forEach { manager.createNotificationChannel(it) }
            Log.d(TAG, "Notification channels created")
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "═══════════════════════════════════════")
        Log.d(TAG, "✅ NEW FCM TOKEN: ${token.take(24)}…")
        Log.d(TAG, "═══════════════════════════════════════")

        // Save token locally
        getSharedPreferences("arveygo_push", Context.MODE_PRIVATE)
            .edit()
            .putString("fcm_token", token)
            .apply()

        // Register with backend if user is logged in
        if (APIService.hasStoredToken) {
            scope.launch {
                try {
                    APIService.registerPushToken(token)
                    Log.d(TAG, "FCM token registered with backend")
                } catch (e: Exception) {
                    Log.d(TAG, "FCM token registration failed: ${e.localizedMessage}")
                }
            }
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        Log.d(TAG, "Message received from: ${message.from}")
        Log.d(TAG, "Data: ${message.data}")

        // Check user's notification preferences
        val prefs = getSharedPreferences("arveygo_notif_prefs", Context.MODE_PRIVATE)
        val type = message.data["type"] ?: ""

        // Check category preferences
        when {
            type.contains("alarm") && !prefs.getBoolean("alarm_notifications", true) -> {
                Log.d(TAG, "Alarm notifications disabled, skipping"); return
            }
            type.contains("maintenance") && !prefs.getBoolean("maintenance_notifications", true) -> {
                Log.d(TAG, "Maintenance notifications disabled, skipping"); return
            }
            type.contains("geofence") && !prefs.getBoolean("geofence_notifications", true) -> {
                Log.d(TAG, "Geofence notifications disabled, skipping"); return
            }
            type.contains("system") && !prefs.getBoolean("system_notifications", true) -> {
                Log.d(TAG, "System notifications disabled, skipping"); return
            }
        }

        // Check quiet hours
        if (prefs.getBoolean("quiet_hours_enabled", false)) {
            if (isInQuietHours(prefs)) {
                Log.d(TAG, "Quiet hours active, skipping notification")
                return
            }
        }

        // Build notification from data payload (for background delivery)
        val title = message.data["title"] ?: message.notification?.title ?: "ArveyGo"
        val body = message.data["body"] ?: message.notification?.body ?: ""
        val channelId = resolveChannel(type)

        showNotification(title, body, channelId, message.data)
    }

    private fun resolveChannel(type: String): String = when {
        type.contains("alarm") || type.contains("speed") || type.contains("engine") -> CHANNEL_ALARM
        type.contains("maintenance") || type.contains("service") || type.contains("document") -> CHANNEL_MAINTENANCE
        type.contains("geofence") || type.contains("zone") -> CHANNEL_GEOFENCE
        else -> CHANNEL_SYSTEM
    }

    private fun showNotification(title: String, body: String, channelId: String, data: Map<String, String>) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data.forEach { (k, v) -> putExtra(k, v) }
        }

        val pendingIntent = PendingIntent.getActivity(
            this, System.currentTimeMillis().toInt(), intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(
                if (channelId == CHANNEL_ALARM || channelId == CHANNEL_GEOFENCE)
                    NotificationCompat.PRIORITY_HIGH
                else NotificationCompat.PRIORITY_DEFAULT
            )
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private fun isInQuietHours(prefs: android.content.SharedPreferences): Boolean {
        val startStr = prefs.getString("quiet_hours_start", "23:00") ?: "23:00"
        val endStr = prefs.getString("quiet_hours_end", "07:00") ?: "07:00"

        val now = java.util.Calendar.getInstance()
        val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)

        val startParts = startStr.split(":")
        val endParts = endStr.split(":")
        val startMinutes = startParts[0].toInt() * 60 + startParts[1].toInt()
        val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()

        return if (startMinutes <= endMinutes) {
            // Same day range: e.g., 09:00 - 17:00
            currentMinutes in startMinutes..endMinutes
        } else {
            // Overnight range: e.g., 23:00 - 07:00
            currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        job.cancel()
    }
}
