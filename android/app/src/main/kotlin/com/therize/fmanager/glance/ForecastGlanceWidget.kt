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

class ForecastGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<HomeWidgetGlanceState>()
            val prefs = state.preferences
            val projectedSpend = (prefs.getString("projectedSpend", "0") ?: "0").toDoubleOrNull() ?: 0.0
            val monthlyBudget = (prefs.getString("monthlyBudget", "0") ?: "0").toDoubleOrNull() ?: 0.0
            val avgDailySpend = (prefs.getString("avgDailySpend", "0") ?: "0").toDoubleOrNull() ?: 0.0

            ForecastContent(context, projectedSpend, monthlyBudget, avgDailySpend)
        }
    }
}

@Composable
fun ForecastContent(context: Context, projected: Double, budget: Double, avgDaily: Double) {
    val isDanger = projected > budget

    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .background(if (isDanger) Color(0xFFCC3300) else Color(0xFF1B5E20))
            .clickable(actionStartActivity<MainActivity>(context))
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(16.dp),
        ) {
            Text(
                text = "DỰ BÁO",
                style = TextStyle(color = ColorProvider(Color(0xB3FFFFFF)), fontSize = 10.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.defaultWeight())

            Text(
                text = WidgetDataHelper.formatCurrency(projected),
                style = TextStyle(color = ColorProvider(Color.White), fontSize = 28.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.height(8.dp))

            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Text(
                    text = "NS: ${WidgetDataHelper.formatCurrency(budget)}",
                    style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 11.sp),
                    modifier = GlanceModifier.defaultWeight()
                )
                Text(
                    text = "${WidgetDataHelper.formatCurrency(avgDaily)}/ngày",
                    style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 11.sp)
                )
            }
        }
    }
}
