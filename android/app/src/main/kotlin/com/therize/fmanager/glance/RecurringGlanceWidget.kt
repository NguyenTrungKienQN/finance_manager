package com.therize.fmanager.glance

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.abs
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

class RecurringGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<HomeWidgetGlanceState>()
            val prefs = state.preferences
            val recurringTitle = prefs.getString("recurringTitle", "Chưa có") ?: "Chưa có"
            val recurringAmount = (prefs.getString("recurringAmount", "0") ?: "0").toDoubleOrNull() ?: 0.0
            val recurringDays = (prefs.getString("recurringDays", "0") ?: "0").toIntOrNull() ?: 0

            RecurringContent(context, recurringTitle, recurringAmount, recurringDays)
        }
    }
}

@Composable
fun RecurringContent(context: Context, title: String, amount: Double, days: Int) {
    val isUrgent = days <= 3

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
            Text(
                text = "ĐỊNH KỲ",
                style = TextStyle(color = ColorProvider(Color(0xB3FFFFFF)), fontSize = 10.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.height(8.dp))

            Text(
                text = title,
                style = TextStyle(color = ColorProvider(Color.White), fontSize = 14.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.defaultWeight())

            Text(
                text = WidgetDataHelper.formatCurrency(amount),
                style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 18.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.height(4.dp))

            Text(
                text = if (days < 0) "Trễ ${abs(days)} ngày" else if (days == 0) "Hôm nay" else "Còn $days ngày",
                style = TextStyle(color = ColorProvider(if (isUrgent) Color(0xFFFF6B4A) else Color(0xFF4FACFE)), fontSize = 11.sp, fontWeight = FontWeight.Bold)
            )
        }
    }
}
