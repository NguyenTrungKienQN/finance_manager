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
            .cornerRadius(28.dp)
            .background(ImageProvider(R.drawable.widget_bg_quick_add))
            .clickable(actionStartActivity<MainActivity>(context, Uri.parse("fmanager://add_transaction"))),
        contentAlignment = Alignment.Center
    ) {
        // Main Action Content (Shifted high to clear the mascot)
        Column(
            modifier = GlanceModifier.fillMaxSize().padding(top = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.Vertical.Top // Start from top
        ) {
            Spacer(modifier = GlanceModifier.height(10.dp))
            
            // Circular Gradient Button with "+"
            Box(
                modifier = GlanceModifier
                    .size(60.dp)
                    .background(ImageProvider(R.drawable.quick_add_button_bg)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "+",
                    style = TextStyle(
                        color = ColorProvider(Color.White), 
                        fontSize = 30.sp, 
                        fontWeight = FontWeight.Bold
                    )
                )
            }
            
            Spacer(modifier = GlanceModifier.height(12.dp))
            
            // Label - ensured enough width to avoid "Thêm nh..."
            Text(
                text = "Thêm nhanh",
                style = TextStyle(
                    color = ColorProvider(Color(0xFF4A4F5A)), 
                    fontSize = 16.sp, 
                    fontWeight = FontWeight.Medium
                ),
                modifier = GlanceModifier.padding(horizontal = 4.dp)
            )
        }
        
        // Mascot Anchored to Bottom Right - Peeking style
        // We use a container Box with fixed height to force clipping of the larger Image
        Box(
            modifier = GlanceModifier.fillMaxSize(),
            contentAlignment = Alignment.BottomEnd
        ) {
            Box(
                modifier = GlanceModifier.size(width = 96.dp, height = 50.dp), // Clipped container
                contentAlignment = Alignment.TopStart
            ) {
                androidx.glance.Image(
                    provider = androidx.glance.ImageProvider(R.drawable.mascot_first),
                    contentDescription = "Mascot",
                    modifier = GlanceModifier.size(96.dp) // Actual large size
                )
            }
        }
    }
}
