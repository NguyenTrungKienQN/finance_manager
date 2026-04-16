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

class SavingsGoalGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<HomeWidgetGlanceState>()
            val prefs = state.preferences
            val topGoalName = prefs.getString("topGoalName", "Tiết kiệm") ?: "Tiết kiệm"
            val topGoalCurrent = (prefs.getString("topGoalCurrent", "0") ?: "0").toDoubleOrNull() ?: 0.0
            val topGoalTarget = (prefs.getString("topGoalTarget", "1") ?: "1").toDoubleOrNull() ?: 1.0

            SavingsGoalContent(context, topGoalName, topGoalCurrent, topGoalTarget)
        }
    }
}

@Composable
fun SavingsGoalContent(context: Context, name: String, current: Double, target: Double) {
    val progress = if (target > 0) (current / target).coerceIn(0.0, 1.0).toFloat() else 0f
    val pct = (progress * 100).toInt()

    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .background(Color(0xFF151528))
            .clickable(actionStartActivity<MainActivity>(context))
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(16.dp),
        ) {
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Text(
                    text = name,
                    style = TextStyle(color = ColorProvider(Color.White), fontSize = 12.sp, fontWeight = FontWeight.Bold),
                    modifier = GlanceModifier.defaultWeight()
                )
                Text(
                    text = "$pct%",
                    style = TextStyle(color = ColorProvider(Color(0xFF34D399)), fontSize = 12.sp, fontWeight = FontWeight.Bold)
                )
            }

            Spacer(modifier = GlanceModifier.defaultWeight())

            Text(
                text = WidgetDataHelper.formatCurrency(current),
                style = TextStyle(color = ColorProvider(Color(0xFF34D399)), fontSize = 28.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.height(8.dp))

            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Text(
                    text = "Mục tiêu:",
                    style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 11.sp),
                    modifier = GlanceModifier.defaultWeight()
                )
                Text(
                    text = WidgetDataHelper.formatCurrency(target),
                    style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 11.sp)
                )
            }
        }
    }
}
