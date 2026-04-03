package com.arveya.arveygo

import android.Manifest
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
import com.arveya.arveygo.ui.theme.ThemeManager
import com.arveya.arveygo.viewmodels.AuthViewModel
import org.osmdroid.config.Configuration
import java.io.File

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
        enableEdgeToEdge()
        ThemeManager.initialize(this)
        configureMaps()

        // Create notification channels
        ArveyGoMessagingService.createNotificationChannels(this)

        // Request notification permission immediately on launch (Android 13+)
        requestNotificationPermission()

        // Restore saved language preference
        com.arveya.arveygo.utils.LoginStrings.initialize(this)
        com.arveya.arveygo.utils.DashboardStrings.initialize(this)

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
            ArveyGoTheme(themeMode = ThemeManager.mode) {
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

    private fun configureMaps() {
        runCatching {
            val basePath = File(cacheDir, "osmdroid").apply { mkdirs() }
            val tileCache = File(basePath, "tiles").apply { mkdirs() }
            Configuration.getInstance().apply {
                userAgentValue = packageName
                osmdroidBasePath = basePath
                osmdroidTileCache = tileCache
            }
        }.onFailure { error ->
            Log.e("Maps", "osmdroid configuration failed", error)
        }
    }
}
