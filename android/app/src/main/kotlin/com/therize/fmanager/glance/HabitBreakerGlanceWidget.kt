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

class HabitBreakerGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<HomeWidgetGlanceState>()
            val prefs = state.preferences
            val habitName = prefs.getString("habitName", "Chưa có") ?: "Chưa có"
            val habitStreak = (prefs.getString("habitStreak", "0") ?: "0").toIntOrNull() ?: 0
            val habitStatus = prefs.getString("habitStatus", "Bắt đầu ngay") ?: "Bắt đầu ngay"

            HabitBreakerContent(context, habitName, habitStreak, habitStatus)
        }
    }
}

@Composable
fun HabitBreakerContent(context: Context, name: String, streak: Int, status: String) {
    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(16.dp)
            .background(Color(0xFF2D1B4E))
            .clickable(actionStartActivity<MainActivity>(context))
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(16.dp),
        ) {
            Text(
                text = name.uppercase(),
                style = TextStyle(color = ColorProvider(Color(0xB3FFFFFF)), fontSize = 10.sp, fontWeight = FontWeight.Bold)
            )

            Spacer(modifier = GlanceModifier.defaultWeight())

            Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                Text(
                    text = "\uD83D\uDD25 $streak",
                    style = TextStyle(color = ColorProvider(Color(0xFFF472B6)), fontSize = 36.sp, fontWeight = FontWeight.Bold)
                )
                Spacer(modifier = GlanceModifier.width(4.dp))
                Text(
                    text = "ngày",
                    style = TextStyle(color = ColorProvider(Color.LightGray), fontSize = 12.sp)
                )
            }

            Spacer(modifier = GlanceModifier.height(8.dp))

            Text(
                text = status,
                style = TextStyle(color = ColorProvider(Color(0xFF4CAF50)), fontSize = 11.sp, fontWeight = FontWeight.Bold)
            )
        }
    }
}
