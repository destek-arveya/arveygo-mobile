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
import com.arveya.arveygo.ui.screens.fleet.RouteHistoryScreen
import com.arveya.arveygo.ui.screens.fleet.VehiclesListScreen
import com.arveya.arveygo.ui.screens.livemap.LiveMapScreen
import com.arveya.arveygo.ui.components.SideMenu
import com.arveya.arveygo.ui.theme.AppColors
import com.arveya.arveygo.viewmodels.AuthViewModel

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

    Box(modifier = Modifier.fillMaxSize()) {
        // Active page
        when (selectedPage) {
            AppPage.DASHBOARD -> DashboardScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.LIVE_MAP -> LiveMapScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.VEHICLES -> VehiclesListScreen(
                onMenuClick = { showSideMenu = true }
            )
            AppPage.ROUTE_HISTORY -> RouteHistoryScreen(
                onMenuClick = { showSideMenu = true }
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
