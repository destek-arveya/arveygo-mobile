package com.arveya.arveygo.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp

@Composable
fun SkeletonBox(
    modifier: Modifier = Modifier,
    shape: androidx.compose.ui.graphics.Shape = RoundedCornerShape(8.dp)
) {
    val transition = rememberInfiniteTransition(label = "skeleton")
    val alpha by transition.animateFloat(
        initialValue = 0.45f,
        targetValue = 0.92f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1100, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "skeleton_alpha"
    )

    Box(
        modifier = modifier
            .clip(shape)
            .alpha(alpha)
            .background(MaterialTheme.colorScheme.surfaceVariant)
    )
}

@Composable
fun DashboardSkeletonBlock() {
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp)
    ) {
        SkeletonBox(
            modifier = Modifier
                .fillMaxWidth()
                .height(190.dp),
            shape = RoundedCornerShape(28.dp)
        )
        SkeletonBox(
            modifier = Modifier
                .fillMaxWidth()
                .height(76.dp),
            shape = RoundedCornerShape(22.dp)
        )
        SkeletonBox(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp),
            shape = RoundedCornerShape(24.dp)
        )
        repeat(2) {
            SkeletonBox(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(148.dp),
                shape = RoundedCornerShape(22.dp)
            )
        }
    }
}

@Composable
fun AlarmEventsSkeletonList() {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        repeat(5) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(12.dp)
            ) {
                SkeletonBox(modifier = Modifier.size(40.dp), shape = CircleShape)
                Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.weight(1f)) {
                    SkeletonBox(modifier = Modifier.fillMaxWidth(0.45f).height(13.dp))
                    SkeletonBox(modifier = Modifier.fillMaxWidth(0.28f).height(10.dp))
                    SkeletonBox(modifier = Modifier.fillMaxWidth(0.72f).height(10.dp))
                }
                SkeletonBox(modifier = Modifier.size(width = 38.dp, height = 10.dp))
            }
        }
    }
}

@Composable
fun AlarmRulesSkeletonList() {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        SkeletonBox(
            modifier = Modifier
                .fillMaxWidth()
                .height(54.dp),
            shape = RoundedCornerShape(12.dp)
        )
        repeat(4) {
            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(12.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                    SkeletonBox(modifier = Modifier.size(38.dp), shape = CircleShape)
                    Column(verticalArrangement = Arrangement.spacedBy(5.dp), modifier = Modifier.weight(1f)) {
                        SkeletonBox(modifier = Modifier.fillMaxWidth(0.42f).height(13.dp))
                        SkeletonBox(modifier = Modifier.fillMaxWidth(0.3f).height(10.dp))
                    }
                    SkeletonBox(
                        modifier = Modifier.size(width = 54.dp, height = 18.dp),
                        shape = RoundedCornerShape(9.dp)
                    )
                }
                SkeletonBox(modifier = Modifier.fillMaxWidth(0.76f).height(10.dp))
                SkeletonBox(modifier = Modifier.fillMaxWidth(0.5f).height(10.dp))
            }
        }
    }
}

@Composable
fun VehicleCardsSkeletonList() {
    Column(
        verticalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        SkeletonBox(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp),
            shape = RoundedCornerShape(12.dp)
        )
        SkeletonBox(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp),
            shape = RoundedCornerShape(16.dp)
        )
        repeat(5) {
            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(12.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                    SkeletonBox(modifier = Modifier.size(40.dp), shape = RoundedCornerShape(12.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(5.dp), modifier = Modifier.weight(1f)) {
                        SkeletonBox(modifier = Modifier.fillMaxWidth(0.28f).height(14.dp))
                        SkeletonBox(modifier = Modifier.fillMaxWidth(0.5f).height(10.dp))
                    }
                    SkeletonBox(
                        modifier = Modifier.size(width = 52.dp, height = 18.dp),
                        shape = RoundedCornerShape(9.dp)
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    repeat(3) {
                        SkeletonBox(
                            modifier = Modifier
                                .weight(1f)
                                .height(48.dp),
                            shape = RoundedCornerShape(10.dp)
                        )
                    }
                }
                Row(modifier = Modifier.fillMaxWidth()) {
                    SkeletonBox(modifier = Modifier.fillMaxWidth(0.35f).height(10.dp))
                    Spacer(modifier = Modifier.weight(1f))
                    SkeletonBox(modifier = Modifier.size(width = 68.dp, height = 10.dp))
                }
            }
        }
    }
}
