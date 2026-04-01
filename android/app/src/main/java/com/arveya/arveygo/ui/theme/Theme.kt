package com.arveya.arveygo.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// MARK: - Theme Colors (matching iOS AppTheme & web CSS variables)
object AppColors {
    // Primary colors
    val Navy = Color(0xFF090F41)
    val Indigo = Color(0xFF4A53A0)
    val Lavender = Color(0xFF8B95E0)

    // Backgrounds
    val Bg = Color(0xFFF5F6FA)
    val Surface = Color.White
    val BgAlt = Color(0xFFF0F1F7)

    // Text
    val TextPrimary = Color(0xFF090F41)
    val TextSecondary = Color(0xFF474E68)
    val TextMuted = Color(0xFF878EA8)
    val TextFaint = Color(0xFFAFB5CA)

    // Status colors
    val Online = Color(0xFF22C55E)
    val Offline = Color(0xFFEF4444)
    val Idle = Color(0xFFF59E0B)

    // Border
    val BorderSoft = Color(0xFFE4E7F0)

    // ── Dark Mode palette (used by VehicleDetailScreen & LiveMap popup) ──
    val DarkBg     = Color(0xFF0A0E1F)   // Page background
    val DarkSurface = Color(0xFF111629)  // Card / sheet background
    val DarkCard   = Color(0xFF1A2040)   // Elevated card
    val DarkBorder = Color(0xFF252D4A)   // Dividers / borders
    val DarkText   = Color(0xFFE8EAF6)   // Primary text
    val DarkTextSub = Color(0xFFB0BAD8)  // Secondary text
    val DarkTextMuted = Color(0xFF6B7699) // Muted / labels

    // Gradients
    val PanelGradient = Brush.linearGradient(
        colors = listOf(
            Color(0xFF0D1550),
            Color(0xFF090F41),
            Color(0xFF060B30)
        )
    )

    val ButtonGradient = Brush.horizontalGradient(
        colors = listOf(Navy, Indigo)
    )
}

// Material 3 color scheme
private val LightColorScheme = lightColorScheme(
    primary = AppColors.Navy,
    onPrimary = Color.White,
    secondary = AppColors.Indigo,
    onSecondary = Color.White,
    background = AppColors.Bg,
    onBackground = AppColors.TextPrimary,
    surface = AppColors.Surface,
    onSurface = AppColors.TextPrimary,
    error = AppColors.Offline,
    onError = Color.White,
    outline = AppColors.BorderSoft,
    surfaceVariant = AppColors.BgAlt,
)

@Composable
fun ArveyGoTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColorScheme,
        shapes = MaterialTheme.shapes.copy(
            small = RoundedCornerShape(8.dp),
            medium = RoundedCornerShape(12.dp),
            large = RoundedCornerShape(16.dp)
        ),
        content = content
    )
}

// Common text styles
object AppTextStyles {
    val heading = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy)
    val subheading = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = AppColors.Navy)
    val body = TextStyle(fontSize = 13.sp, color = AppColors.TextSecondary)
    val caption = TextStyle(fontSize = 11.sp, color = AppColors.TextMuted)
    val tiny = TextStyle(fontSize = 10.sp, color = AppColors.TextFaint)
    val label = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AppColors.TextSecondary)
}
