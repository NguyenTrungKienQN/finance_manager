package com.therize.fmanager.glance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import com.therize.fmanager.MainActivity
import com.therize.fmanager.R
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class DailyBalanceWidgetReceiver : HomeWidgetGlanceWidgetReceiver<DailyBalanceGlanceWidget>() {
    override val glanceAppWidget = DailyBalanceGlanceWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetClickHelper.setPendingIntent(context, appWidgetManager, appWidgetIds)
    }
}

class WeeklySummaryWidgetReceiver : HomeWidgetGlanceWidgetReceiver<WeeklySummaryGlanceWidget>() {
    override val glanceAppWidget = WeeklySummaryGlanceWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetClickHelper.setPendingIntent(context, appWidgetManager, appWidgetIds)
    }
}

class ForecastWidgetReceiver : HomeWidgetGlanceWidgetReceiver<ForecastGlanceWidget>() {
    override val glanceAppWidget = ForecastGlanceWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetClickHelper.setPendingIntent(context, appWidgetManager, appWidgetIds)
    }
}

class SavingsGoalWidgetReceiver : HomeWidgetGlanceWidgetReceiver<SavingsGoalGlanceWidget>() {
    override val glanceAppWidget = SavingsGoalGlanceWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetClickHelper.setPendingIntent(context, appWidgetManager, appWidgetIds)
    }
}

class QuickAddWidgetReceiver : HomeWidgetGlanceWidgetReceiver<QuickAddGlanceWidget>() {
    override val glanceAppWidget = QuickAddGlanceWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetClickHelper.setPendingIntent(context, appWidgetManager, appWidgetIds)
    }
}

class HabitBreakerWidgetReceiver : HomeWidgetGlanceWidgetReceiver<HabitBreakerGlanceWidget>() {
    override val glanceAppWidget = HabitBreakerGlanceWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetClickHelper.setPendingIntent(context, appWidgetManager, appWidgetIds)
    }
}

class RecurringWidgetReceiver : HomeWidgetGlanceWidgetReceiver<RecurringGlanceWidget>() {
    override val glanceAppWidget = RecurringGlanceWidget()

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        WidgetClickHelper.setPendingIntent(context, appWidgetManager, appWidgetIds)
    }
}

/**
 * Helper to set a PendingIntent on the widget's root view.
 * This is essential for MIUI/HyperOS launchers to detect the widget
 * bounds and produce the native widget-to-app zoom animation.
 */
object WidgetClickHelper {
    fun setPendingIntent(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            val pendingIntent = PendingIntent.getActivity(context, appWidgetId, intent, flags)

            // Get the current RemoteViews from the widget and set the click on the root
            val views = appWidgetManager.getAppWidgetInfo(appWidgetId)?.let { info ->
                RemoteViews(context.packageName, info.initialLayout).apply {
                    setOnClickPendingIntent(android.R.id.background, pendingIntent)
                }
            }
            if (views != null) {
                appWidgetManager.partiallyUpdateAppWidget(appWidgetId, views)
            }
        }
    }
}
