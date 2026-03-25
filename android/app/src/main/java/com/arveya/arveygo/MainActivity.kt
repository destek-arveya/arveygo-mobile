package com.arveya.arveygo

import android.app.UiModeManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.arveya.arveygo.services.WebSocketManager
import com.arveya.arveygo.ui.theme.ArveyGoTheme
import com.arveya.arveygo.viewmodels.AuthViewModel

val LocalAuthViewModel = staticCompositionLocalOf<AuthViewModel> {
    error("AuthViewModel not provided")
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Force light mode — disable dark theme
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val uiModeManager = getSystemService(UiModeManager::class.java)
            uiModeManager?.setApplicationNightMode(UiModeManager.MODE_NIGHT_NO)
        }
        enableEdgeToEdge()

        // Lifecycle observer for WebSocket reconnection
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                // App coming to foreground — reconnect WebSocket
                Log.d("WS", "App entering foreground — triggering reconnect")
                WebSocketManager.reconnect()
            }

            override fun onStop(owner: LifecycleOwner) {
                // App going to background — optionally disconnect to save battery
                // WebSocketManager.disconnect()
                Log.d("WS", "App entering background")
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
}
