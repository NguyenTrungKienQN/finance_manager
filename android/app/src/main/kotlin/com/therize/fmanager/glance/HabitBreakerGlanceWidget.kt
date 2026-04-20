package com.therize.fmanager.glance

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.ImageProvider
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
import com.therize.fmanager.R
import com.therize.fmanager.MainActivity

class HabitBreakerGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val state = currentState<HomeWidgetGlanceState>()
            val prefs = state.preferences
            val habitName = prefs.getString("habitName", null)
            val habitStreak = (prefs.getString("habitStreak", "0") ?: "0").toIntOrNull() ?: 0
            val habitStatus = prefs.getString("habitStatus", "Tạo thử thách để bắt đầu") ?: "Tạo thử thách để bắt đầu"
            val habitWidgetState = prefs.getString("habitWidgetState", "none") ?: "none"

            HabitBreakerContent(context, habitName, habitStreak, habitStatus, habitWidgetState)
        }
    }
}

@Composable
fun HabitBreakerContent(
    context: Context,
    name: String?,
    streak: Int,
    status: String,
    widgetState: String
) {
    // Determine display values based on state
    val mascotDrawable = when (widgetState) {
        "active" -> R.drawable.mascot_first
        "failed" -> R.drawable.mascot_sad
        "frozen" -> R.drawable.mascot_wait
        else -> R.drawable.mascot_wait // "none" or unknown
    }
    val mainText = when (widgetState) {
        "active", "failed", "frozen" -> name ?: "Thử thách"
        else -> "Chưa có thử thách"
    }
    val subText = status

    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(28.dp)
            .background(ImageProvider(R.drawable.widget_bg_habit))
            .clickable(actionStartActivity<MainActivity>(context)),
        contentAlignment = Alignment.Center
    ) {
        Row(
            modifier = GlanceModifier.fillMaxSize().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Mascot on the left (~40% width)
            Box(
                modifier = GlanceModifier.size(width = 110.dp, height = 130.dp),
                contentAlignment = Alignment.Center
            ) {
                androidx.glance.Image(
                    provider = ImageProvider(mascotDrawable),
                    contentDescription = "Mascot",
                    modifier = GlanceModifier.size(width = 110.dp, height = 130.dp)
                )
            }

            Spacer(modifier = GlanceModifier.width(16.dp))

            // Text content on the right
            Column(
                modifier = GlanceModifier.defaultWeight(),
                verticalAlignment = Alignment.Vertical.CenterVertically
            ) {
                // Header: 🔥 Thử thách
                Text(
                    text = "🔥 Thử thách",
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF5A3E36)),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    )
                )

                Spacer(modifier = GlanceModifier.height(12.dp))

                // Main text (challenge name or status)
                Text(
                    text = mainText,
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF5A3E36)),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    maxLines = 2
                )

                Spacer(modifier = GlanceModifier.height(10.dp))

                // Subtext
                Text(
                    text = subText,
                    style = TextStyle(
                        color = ColorProvider(Color(0xFF7A5C50)),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Normal
                    ),
                    maxLines = 1
                )
            }
        }
    }
}
