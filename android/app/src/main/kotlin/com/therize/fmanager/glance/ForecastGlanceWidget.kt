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

import androidx.glance.Image
import androidx.glance.ImageProvider
import com.therize.fmanager.R
import java.util.Calendar

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
    
    // Estimate current spend internally in widget since we only have projected and avgDaily natively stored
    val cal = Calendar.getInstance()
    val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)
    val today = cal.get(Calendar.DAY_OF_MONTH)
    val daysRemaining = daysInMonth - today

    val currentSpend = projected - (avgDaily * daysRemaining)

    var headline = "Bạn đang chi tiêu\nổn định"
    var subtitle = "Chưa có dấu hiệu vượt hạn mức"
    var mascotId = R.drawable.mascot_defaultpose

    if (isDanger && avgDaily > 0) {
        var daysLeft = ((budget - currentSpend) / avgDaily).toInt()
        if (daysLeft < 0) daysLeft = 0
        
        val futureCal = Calendar.getInstance()
        futureCal.add(Calendar.DAY_OF_YEAR, daysLeft)
        
        val weekdayStr = when(futureCal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SUNDAY -> "Chủ nhật"
            Calendar.MONDAY -> "Thứ 2"
            Calendar.TUESDAY -> "Thứ 3"
            Calendar.WEDNESDAY -> "Thứ 4"
            Calendar.THURSDAY -> "Thứ 5"
            Calendar.FRIDAY -> "Thứ 6"
            else -> "Thứ 7"
        }
        
        if (daysLeft == 0) {
            headline = "Bạn đã hết tiền\nhôm nay"
        } else if (daysLeft == 1) {
            headline = "Bạn sẽ hết tiền\nvào ngày mai"
        } else {
            headline = "Bạn sẽ hết tiền\nvào $weekdayStr"
        }
        subtitle = "Nếu giữ mức chi hiện tại"
        mascotId = R.drawable.mascot_sad
    }

    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .background(ImageProvider(R.drawable.widget_bg_forecast))
            .clickable(actionStartActivity<MainActivity>(context))
    ) {
        // Text Content
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(22.dp),
        ) {
            Text(
                text = "DỰ BÁO",
                style = TextStyle(
                    color = ColorProvider(Color(0xB3FFFFFF)), 
                    fontSize = 11.sp, 
                    fontWeight = FontWeight.Normal
                )
            )
            
            Spacer(modifier = GlanceModifier.height(8.dp))
            
            Text(
                text = headline,
                style = TextStyle(
                    color = ColorProvider(Color.White), 
                    fontSize = 24.sp, 
                    fontWeight = FontWeight.Bold
                )
            )
            
            Spacer(modifier = GlanceModifier.height(6.dp))
            
            Text(
                text = subtitle,
                style = TextStyle(
                    color = ColorProvider(Color(0xB3FFFFFF)), 
                    fontSize = 14.sp
                )
            )
        }
        
        // Mascot positioned strictly to Bottom-Right
        Box(
            modifier = GlanceModifier.fillMaxSize(),
            contentAlignment = Alignment.BottomEnd
        ) {
            Image(
                provider = ImageProvider(mascotId),
                contentDescription = "Mascot Indicator",
                modifier = GlanceModifier.height(115.dp).padding(end = 4.dp, bottom = 4.dp)
            )
        }
    }
}
