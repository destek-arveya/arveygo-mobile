package com.arveya.arveygo.ui.components

import androidx.compose.animation.core.*
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.arveya.arveygo.models.*
import com.arveya.arveygo.ui.theme.AppColors

// MARK: - Status Badge
@Composable
fun StatusBadge(status: VehicleStatus) {
    Text(
        text = status.label,
        fontSize = 10.sp,
        fontWeight = FontWeight.Medium,
        color = status.color,
        modifier = Modifier
            .background(status.color.copy(alpha = 0.1f), RoundedCornerShape(20.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    )
}

// MARK: - Avatar Circle
@Composable
fun AvatarCircle(
    initials: String,
    color: Color = AppColors.Navy,
    size: Dp = 32.dp
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(color)
    ) {
        Text(
            text = initials,
            fontSize = (size.value * 0.35f).sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
    }
}

// MARK: - Metric Card
@Composable
fun MetricCard(metric: DashboardMetric) {
    Column(
        modifier = Modifier
            .width(140.dp)
            .background(AppColors.Surface)
            .padding(16.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                text = metric.value,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = if (metric.iconColor == AppColors.Online) AppColors.Online else AppColors.Navy
            )
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(32.dp)
                    .background(metric.iconBg, RoundedCornerShape(8.dp))
            ) {
                Icon(
                    imageVector = metricIcon(metric.icon),
                    contentDescription = null,
                    tint = metric.iconColor,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = metric.title,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            color = AppColors.TextMuted
        )
        Spacer(modifier = Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = when (metric.changeType) {
                    ChangeType.UP -> Icons.Default.KeyboardArrowUp
                    ChangeType.DOWN -> Icons.Default.KeyboardArrowDown
                    ChangeType.FLAT -> Icons.Default.Remove
                },
                contentDescription = null,
                tint = metric.changeType.color,
                modifier = Modifier.size(12.dp)
            )
            Spacer(modifier = Modifier.width(3.dp))
            Text(
                text = metric.change,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = metric.changeType.color
            )
        }
    }
}

// MARK: - Card Container
@Composable
fun CardView(
    title: String,
    count: String? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(14.dp))
    ) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            Text(
                text = title,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Navy
            )
            if (count != null) {
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = count,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = AppColors.TextMuted,
                    modifier = Modifier
                        .background(AppColors.Bg, RoundedCornerShape(20.dp))
                        .padding(horizontal = 8.dp, vertical = 2.dp)
                )
            }
            Spacer(modifier = Modifier.weight(1f))
            if (actionLabel != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.clickable { onAction?.invoke() }
                ) {
                    Text(
                        text = actionLabel,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = AppColors.Indigo
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = AppColors.Indigo,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }
        }
        content()
    }
}

// MARK: - Loading Spinner
@Composable
fun LoadingSpinner(color: Color = Color.White, size: Dp = 20.dp) {
    val infiniteTransition = rememberInfiniteTransition(label = "spinner")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(800, easing = LinearEasing)),
        label = "rotation"
    )
    CircularProgressIndicator(
        strokeWidth = 2.5.dp,
        color = color,
        modifier = Modifier
            .size(size)
            .rotate(rotation)
    )
}

// MARK: - Gradient Button
@Composable
fun GradientButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    isLoading: Boolean = false,
    enabled: Boolean = true,
    icon: ImageVector? = null
) {
    Button(
        onClick = onClick,
        enabled = enabled && !isLoading,
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        contentPadding = PaddingValues(0.dp),
        shape = RoundedCornerShape(12.dp),
        modifier = modifier.height(50.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxSize()
                .background(AppColors.ButtonGradient, RoundedCornerShape(12.dp))
        ) {
            if (isLoading) {
                LoadingSpinner()
            } else {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = text,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    if (icon != null) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Icon(
                            imageVector = icon,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Language Switcher (Dropdown Picker)
@Composable
fun LanguageSwitcher() {
    val selectedLang by com.arveya.arveygo.utils.LoginStrings.currentLang.collectAsState()
    var expanded by remember { mutableStateOf(false) }
    val languages = listOf(
        Triple("TR", "🇹🇷", "Türkçe"),
        Triple("EN", "🇬🇧", "English"),
        Triple("ES", "🇪🇸", "Español"),
        Triple("FR", "🇫🇷", "Français")
    )

    Box {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .background(AppColors.Bg, RoundedCornerShape(8.dp))
                .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(8.dp))
                .clickable { expanded = true }
                .padding(horizontal = 10.dp, vertical = 6.dp)
        ) {
            val flag = languages.firstOrNull { it.first == selectedLang }?.second ?: "🇹🇷"
            Text(flag, fontSize = 14.sp)
            Spacer(Modifier.width(5.dp))
            Text(
                text = selectedLang,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = AppColors.Navy
            )
            Spacer(Modifier.width(4.dp))
            Icon(
                Icons.Default.ArrowDropDown, null,
                tint = AppColors.TextMuted,
                modifier = Modifier.size(14.dp)
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            languages.forEach { (code, flag, name) ->
                DropdownMenuItem(
                    text = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("$flag  $name", fontSize = 13.sp)
                            if (selectedLang == code) {
                                Spacer(Modifier.width(8.dp))
                                Icon(Icons.Default.Check, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
                            }
                        }
                    },
                    onClick = {
                        com.arveya.arveygo.utils.LoginStrings.setLanguage(code)
                        com.arveya.arveygo.utils.DashboardStrings.setLanguage(code)
                        expanded = false
                    }
                )
            }
        }
    }
}

// MARK: - Section Card
@Composable
fun SectionCard(
    title: String,
    icon: ImageVector,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Surface, RoundedCornerShape(14.dp))
            .border(1.dp, AppColors.BorderSoft, RoundedCornerShape(14.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = AppColors.Indigo, modifier = Modifier.size(14.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = AppColors.TextMuted, letterSpacing = 0.5.sp)
        }
        Spacer(Modifier.height(12.dp))
        content()
    }
}

// MARK: - Info Cell
@Composable
fun InfoCell(icon: ImageVector, label: String, value: String, color: Color = AppColors.Indigo) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(AppColors.Bg, RoundedCornerShape(10.dp))
            .padding(10.dp)
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(26.dp)
                .background(color.copy(alpha = 0.08f), RoundedCornerShape(7.dp))
        ) {
            Icon(icon, null, tint = color, modifier = Modifier.size(12.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(label, fontSize = 8.sp, fontWeight = FontWeight.Bold, color = AppColors.TextFaint, letterSpacing = 0.3.sp)
            Text(value, fontSize = 12.sp, fontWeight = FontWeight.Bold, color = AppColors.Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
    }
}

// Helper to get icons
fun metricIcon(name: String): ImageVector = when (name) {
    "car" -> Icons.Default.DirectionsCar
    "check_circle" -> Icons.Default.CheckCircle
    "cancel" -> Icons.Default.Cancel
    "pause_circle" -> Icons.Default.PauseCircle
    "road" -> Icons.Default.Route
    else -> Icons.Default.Info
}
