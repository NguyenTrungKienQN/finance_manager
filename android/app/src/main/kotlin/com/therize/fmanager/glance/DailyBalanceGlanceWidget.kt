package com.therize.fmanager.glance

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.*
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.text.FontWeight
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import com.therize.fmanager.MainActivity

class DailyBalanceGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<HomeWidgetGlanceState>()
            val prefs = state.preferences
            val spent = (prefs.getString("todaySpent", "0") ?: "0").toDoubleOrNull() ?: 0.0
            val limit = (prefs.getString("dailyLimit", "0") ?: "0").toDoubleOrNull() ?: 0.0

            DailyBalanceContent(context, spent, limit)
        }
    }
}

@Composable
fun DailyBalanceContent(context: Context, spent: Double, limit: Double) {
    val remaining = limit - spent
    val isOver = remaining < 0
    val progress = if (limit > 0) (spent / limit).coerceIn(0.0, 1.0) else 0.0
    val bottomHeight = 85.dp

    // Root Box tags this view with @android:id/background for animations
    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(24.dp)
            .clickable(actionStartActivity<MainActivity>(context)),
        contentAlignment = androidx.glance.layout.Alignment.TopStart
    ) {
        // LAYER 1: Background Split (Top Gradient, Bottom Solid)
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Box(modifier = GlanceModifier.fillMaxWidth().defaultWeight()
                .background(androidx.glance.ImageProvider(com.therize.fmanager.R.drawable.widget_gradient_top))) {}
            Box(modifier = GlanceModifier.fillMaxWidth().height(bottomHeight)
                .background(Color(0xFFF2F2F7))) {}
        }

        // LAYER 2: Content (Amount, Sliders, Text)
        Column(modifier = GlanceModifier.fillMaxSize()) {
            // TOP Content
            Column(
                modifier = GlanceModifier.fillMaxWidth().defaultWeight()
                    .padding(start = 20.dp, end = 20.dp, top = 20.dp)
            ) {
                Text(
                    text = "HÔM NAY",
                    style = TextStyle(color = ColorProvider(Color.White.copy(alpha = 0.8f)), fontSize = 13.sp, fontWeight = FontWeight.Medium)
                )

                Text(
                    text = WidgetDataHelper.formatCurrency(remaining),
                    style = TextStyle(color = ColorProvider(Color.White), fontSize = 32.sp, fontWeight = FontWeight.Bold)
                )

                Text(
                    text = if (spent > 0) "Còn lại" else "Chưa chi tiêu",
                    style = TextStyle(color = ColorProvider(Color.White.copy(alpha = 0.85f)), fontSize = 15.sp)
                )
                
                Spacer(modifier = GlanceModifier.height(10.dp))

                // Progress Bar wrapper
                Box(modifier = GlanceModifier.fillMaxWidth().height(8.dp).background(androidx.glance.ImageProvider(com.therize.fmanager.R.drawable.widget_progress_bar_bg))) {
                    if (progress > 0) {
                        androidx.glance.appwidget.LinearProgressIndicator(
                            progress = progress.toFloat(),
                            color = ColorProvider(Color(0xFFFF7A7A)),
                            backgroundColor = ColorProvider(Color.Transparent),
                            modifier = GlanceModifier.fillMaxSize()
                        )
                    }
                }
            }

            // BOTTOM Content
            Box(
                modifier = GlanceModifier.fillMaxWidth().height(bottomHeight).padding(start = 20.dp, end = 20.dp)
            ) {
                Column(modifier = GlanceModifier.fillMaxHeight()) {
                    Spacer(modifier = GlanceModifier.defaultWeight())
                    // Limit text width to 70% to avoid being blocked by the massive mascot
                    Row(modifier = GlanceModifier.fillMaxWidth()) {
                        Box(modifier = GlanceModifier.defaultWeight()) {
                            Text(
                                text = if (isOver) "Đã vượt hạn mức." else "Bạn đang tiêu rất tốt hôm nay.",
                                style = TextStyle(color = ColorProvider(Color(0xFF6B6B6B)), fontSize = 13.sp)
                            )
                        }
                        Spacer(modifier = GlanceModifier.width(60.dp)) // Reserve space for mascot base
                    }
                    Spacer(modifier = GlanceModifier.defaultWeight())
                }
            }
        }

        // LAYER 3: Mascot Overlay (Enlarged and pinned to Right)
        Row(modifier = GlanceModifier.fillMaxSize()) {
            Spacer(modifier = GlanceModifier.defaultWeight())
            Column(modifier = GlanceModifier.fillMaxHeight()) {
                Spacer(modifier = GlanceModifier.defaultWeight())
                // Huge Mascot Box
                Box(modifier = GlanceModifier.height(140.dp).width(120.dp)) {
                    androidx.glance.Image(
                        provider = androidx.glance.ImageProvider(com.therize.fmanager.R.drawable.mascot_defaultpose),
                        contentDescription = "Mascot",
                        modifier = GlanceModifier.height(180.dp).width(120.dp)
                            .padding(top = 40.dp) // Pushes it down so bottom is clipped
                    )
                }
            }
        }
    }
}
