package com.therize.fmanager.glance

import android.content.Context
import android.net.Uri
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
import androidx.glance.layout.*
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.text.FontWeight
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import com.therize.fmanager.R
import com.therize.fmanager.MainActivity

class QuickAddGlanceWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            QuickAddContent(context)
        }
    }
}

@Composable
fun QuickAddContent(context: Context) {
    Box(
        modifier = GlanceModifier.fillMaxSize()
            .appWidgetBackground()
            .cornerRadius(28.dp) // Large premium rounding
            .background(ImageProvider(R.drawable.widget_bg_gradient)) // Rich dark blue/black depth
            .clickable(actionStartActivity<MainActivity>(context, Uri.parse("fmanager://add_transaction"))),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.Vertical.CenterVertically
        ) {
            Box(
                modifier = GlanceModifier
                    .size(60.dp)
                    .background(ImageProvider(R.drawable.quick_add_glow_gradient)) // High-tech cyan-blue glowing gradient
                    .cornerRadius(30.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "+",
                    style = TextStyle(
                        color = ColorProvider(Color.White), 
                        fontSize = 32.sp, 
                        fontWeight = FontWeight.Bold
                    )
                )
            }
            Spacer(modifier = GlanceModifier.height(10.dp))
            Text(
                text = "Thêm Nhanh",
                style = TextStyle(
                    color = ColorProvider(Color(0xFFE0E0E0)), 
                    fontSize = 11.sp, 
                    fontWeight = FontWeight.Medium
                )
            )
        }
    }
}
