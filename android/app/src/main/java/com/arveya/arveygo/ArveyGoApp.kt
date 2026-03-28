package com.arveya.arveygo

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.arveya.arveygo.ui.navigation.AppPage
import com.arveya.arveygo.ui.screens.auth.LoginScreen
import com.arveya.arveygo.ui.screens.dashboard.DashboardScreen
import com.arveya.arveygo.ui.screens.fleet.AlarmsScreen
import com.arveya.arveygo.ui.screens.fleet.DriversScreen
import com.arveya.arveygo.ui.screens.fleet.FleetManagementScreen
import com.arveya.arveygo.ui.screens.fleet.GeofencesScreen
import com.arveya.arveygo.ui.screens.fleet.RouteHistoryScreen
import com.arveya.arveygo.ui.screens.fleet.VehiclesListScreen
import com.arveya.arveygo.ui.screens.livemap.LiveMapScreen
import com.arveya.arveygo.ui.screens.settings.SettingsScreen
import com.arveya.arveygo.ui.screens.support.SupportRequestScreen
import com.arveya.arveygo.ui.components.SideMenu
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.viewmodels.AuthViewModel
import com.arveya.arveygo.services.WebSocketManager

@Composable
fun ArveyGoApp(authVM: AuthViewModel) {
    val isLoggedIn by authVM.isLoggedIn.collectAsState()

    AnimatedContent(
        targetState = isLoggedIn,
        transitionSpec = {
            if (targetState) {
                slideInHorizontally { it } + fadeIn() togetherWith
                        slideOutHorizontally { -it } + fadeOut()
            } else {
                slideInHorizontally { -it } + fadeIn() togetherWith
                        slideOutHorizontally { it } + fadeOut()
            }
        },
        label = "auth_transition"
    ) { loggedIn ->
        if (loggedIn) {
            MainContent(authVM = authVM)
        } else {
            LoginScreen()
        }
    }
}

@Composable
fun MainContent(authVM: AuthViewModel) {
    var selectedPage by remember { mutableStateOf(AppPage.DASHBOARD) }
    var showSideMenu by remember { mutableStateOf(false) }
    var showSupportRequest by remember { mutableStateOf(false) }
    var alarmsSearchText by remember { mutableStateOf("") }

    // Observe consecutive failures to trigger support request page
    val consecutiveFailures by WebSocketManager.consecutiveFailures.collectAsState()
    LaunchedEffect(consecutiveFailures) {
        if (consecutiveFailures >= WebSocketManager.MAX_CONSECUTIVE_FAILURES) {
            showSupportRequest = true
        }
    }

    // If support request is showing, overlay it
    if (showSupportRequest) {
        SupportRequestScreen(onBack = { showSupportRequest = false })
        return
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Active page
        when (selectedPage) {
            AppPage.DASHBOARD -> DashboardScreen(
                onMenuClick = { showSideMenu = true },
                onNavigateToMap = { selectedPage = AppPage.LIVE_MAP },
                onNavigateToVehicles = { selectedPage = AppPage.VEHICLES },
                onNavigateToDrivers = { selectedPage = AppPage.DRIVERS },
                onNavigateToAlarms = { searchText -> alarmsSearchText = searchText; selectedPage = AppPage.ALARMS },
                onNavigateToRouteHistory = { selectedPage = AppPage.ROUTE_HISTORY }
            )
            AppPage.LIVE_MAP -> LiveMapScreen(
                onMenuClick = { showSideMenu = true },
                onNavigateToRouteHistory = { _ -> selectedPage = AppPage.ROUTE_HISTORY },
                onNavigateToAlarms = { alarmsSearchText = ""; selectedPage = AppPage.ALARMS }
            )
            AppPage.VEHICLES -> VehiclesListScreen(
                onMenuClick = { showSideMenu = true },
                onNavigateToRouteHistory = { _ -> selectedPage = AppPage.ROUTE_HISTORY },
                onNavigateToAlarms = { alarmsSearchText = ""; selectedPage = AppPage.ALARMS }
            )
            AppPage.DRIVERS -> DriversScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.ROUTE_HISTORY -> RouteHistoryScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.ALARMS -> AlarmsScreen(
                onMenuClick = { showSideMenu = true },
                initialSearchText = alarmsSearchText
            )
            AppPage.GEOFENCES -> GeofencesScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.FLEET_MANAGEMENT -> FleetManagementScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.SETTINGS -> SettingsScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.SUPPORT -> SupportRequestScreen(
                onBack = { selectedPage = AppPage.DASHBOARD },
                showSideMenu = { showSideMenu = true }
            )
        }

        // Overlay
        AnimatedVisibility(
            visible = showSideMenu,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(AppColors.Navy.copy(alpha = 0.3f))
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() }
                    ) { showSideMenu = false }
            )
        }

        // Side menu
        SideMenu(
            isShowing = showSideMenu,
            selectedPage = selectedPage,
            onPageSelected = {
                if (it == AppPage.ALARMS) alarmsSearchText = ""
                selectedPage = it
                showSideMenu = false
            },
            onClose = { showSideMenu = false },
            onLogout = {
                showSideMenu = false
                authVM.logout()
            }
        )
    }
}
