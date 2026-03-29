package com.arveya.arveygo

import android.Manifest
import android.app.UiModeManager
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.core.content.ContextCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arveya.arveygo.services.ArveyGoMessagingService
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.theme.ArveyGoTheme
import com.arveya.arveygo.viewmodels.AuthViewModel

val LocalAuthViewModel = staticCompositionLocalOf<AuthViewModel> {
    error("AuthViewModel not provided")
}

class MainActivity : ComponentActivity() {

    // Android 13+ notification permission launcher
    private val notifPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        Log.d("Push", "POST_NOTIFICATIONS permission granted: $granted")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Force light mode — disable dark theme
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val uiModeManager = getSystemService(UiModeManager::class.java)
            uiModeManager?.setApplicationNightMode(UiModeManager.MODE_NIGHT_NO)
        }
        enableEdgeToEdge()

        // Create notification channels
        ArveyGoMessagingService.createNotificationChannels(this)

        // Request notification permission immediately on launch (Android 13+)
        requestNotificationPermission()

        // Lifecycle observer for WebSocket reconnection
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                // App coming to foreground — smart reconnect
                Log.d("WS", "App entering foreground — triggering reconnect")
                WebSocketManager.onForeground()
            }

            override fun onStop(owner: LifecycleOwner) {
                // App going to background — stop pings, track timestamp
                Log.d("WS", "App entering background")
                WebSocketManager.onBackground()
            }
        })

        setContent {
            ArveyGoTheme {
                val authVM: AuthViewModel = viewModel()
                CompositionLocalProvider(LocalAuthViewModel provides authVM) {
                    ArveyGoApp(authVM = authVM)
                }
            }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                notifPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }
}
