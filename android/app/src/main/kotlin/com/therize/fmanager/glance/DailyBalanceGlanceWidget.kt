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

    // Outer Box with appWidgetBackground() tags this view with @android:id/background
    // Required for MIUI/HyperOS launchers to detect widget bounds for zoom animation
    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .background(if (isOver) Color(0xFFB71C1C) else Color(0xFF1A237E))
            .clickable(actionStartActivity<MainActivity>(context))
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(16.dp),
        ) {
            Text(
                text = "HÔM NAY",
                style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 10.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.defaultWeight())

            Text(
                text = WidgetDataHelper.formatCurrency(remaining),
                style = TextStyle(color = ColorProvider(if (isOver) Color(0xFFFFCDD2) else Color.White), fontSize = 28.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.height(8.dp))

            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Text(
                    text = "Chi: ${WidgetDataHelper.formatCurrency(spent)}",
                    style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 11.sp),
                    modifier = GlanceModifier.defaultWeight()
                )
                Text(
                    text = "HM: ${WidgetDataHelper.formatCurrency(limit)}",
                    style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 11.sp)
                )
            }
        }
    }
}
