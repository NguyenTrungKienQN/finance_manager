package com.therize.fmanager

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

class DailyBalanceWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_daily_balance)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val fmt = NumberFormat.getInstance(Locale("vi", "VN"))

                val todaySpent = prefs.getString("todaySpent", "0")?.toFloatOrNull() ?: 0f
                val dailyLimit = prefs.getString("dailyLimit", "0")?.toFloatOrNull() ?: 0f
                val remaining = dailyLimit - todaySpent

                // Values
                views.setTextViewText(R.id.daily_spent_value, "Chi: ${fmt.format(todaySpent.toLong())}₫")
                views.setTextViewText(R.id.daily_remaining_value, "${fmt.format(remaining.toLong())}₫")
                views.setTextViewText(R.id.daily_limit_value, "Hạn mức: ${fmt.format(dailyLimit.toLong())}₫")

                // Progress Bar
                val progress = if (dailyLimit > 0) ((todaySpent / dailyLimit) * 100).toInt() else 0
                views.setProgressBar(R.id.daily_progress, 100, progress.coerceIn(0, 100), false)

                // Styling based on status
                if (remaining < 0) {
                    views.setTextViewText(R.id.daily_remaining_label, "⚠ Vượt hạn mức")
                    views.setTextColor(R.id.daily_remaining_value, 0xFFEF5350.toInt()) // Red
                } else {
                    views.setTextViewText(R.id.daily_remaining_label, "Trong hạn mức")
                    views.setTextColor(R.id.daily_remaining_value, 0xFF4CAF50.toInt()) // Green
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}

class WeeklySummaryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_weekly_summary)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val fmt = NumberFormat.getInstance(Locale("vi", "VN"))

                val weeklyTotal = prefs.getString("weeklyTotal", "0")?.toFloatOrNull() ?: 0f
                val weeklyAvg = prefs.getString("weeklyAvg", "0")?.toFloatOrNull() ?: 0f
                
                // Set text values
                views.setTextViewText(R.id.weekly_total_value, "${fmt.format(weeklyTotal.toLong())}₫")
                views.setTextViewText(R.id.footer, "TB/ngày: ${fmt.format(weeklyAvg.toLong())}₫")

                // Update Bar Chart
                val days = (0..6).map { prefs.getString("day$it", "0")?.toFloatOrNull() ?: 0f }
                val max = days.maxOrNull() ?: 0f
                val safeMax = if (max == 0f) 1f else max

                days.forEachIndexed { index, value ->
                    val progress = ((value / safeMax) * 100).toInt()
                    // Dynamically find ID: bar_0, bar_1, etc.
                    val barId = resultId(context, "bar_$index")
                    if (barId != 0) {
                        views.setProgressBar(barId, 100, progress.coerceIn(0, 100), false)
                    }
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    private fun resultId(context: Context, name: String): Int {
        return context.resources.getIdentifier(name, "id", context.packageName)
    }
}

class ForecastWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_forecast)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val fmt = NumberFormat.getInstance(Locale("vi", "VN"))

                val projectedTotal = prefs.getString("projectedTotal", "0")?.toFloatOrNull() ?: 0f
                val monthlyBudget = prefs.getString("monthlyBudget", "0")?.toFloatOrNull() ?: 0f
                val monthlySpent = prefs.getString("monthlySpent", "0")?.toFloatOrNull() ?: 0f
                val avgDaily = prefs.getString("avgDailySpend", "0")?.toFloatOrNull() ?: 0f
                
                val isDanger = projectedTotal > monthlyBudget

                // Values
                views.setTextViewText(R.id.forecast_projected_value, "${fmt.format(projectedTotal.toLong())}₫")
                views.setTextViewText(R.id.forecast_budget_value, "Ngân sách: ${fmt.format(monthlyBudget.toLong())}₫")
                views.setTextViewText(R.id.forecast_avg_value, "TB/ngày: ${fmt.format(avgDaily.toLong())}₫")

                // Progress Bar (Spent vs Budget)
                val progress = if (monthlyBudget > 0) ((monthlySpent / monthlyBudget) * 100).toInt() else 0
                views.setProgressBar(R.id.forecast_progress, 100, progress.coerceIn(0, 100), false)

                // Status Pill Styling
                if (isDanger) {
                    views.setTextViewText(R.id.forecast_status, "⚠ Vượt chi")
                    views.setTextColor(R.id.forecast_status, 0xFFEF5350.toInt())
                } else {
                    views.setTextViewText(R.id.forecast_status, "✓ Ổn định")
                    views.setTextColor(R.id.forecast_status, 0xFF4CAF50.toInt())
                }
                
                // Color projected value based on danger
                if (isDanger) {
                     views.setTextColor(R.id.forecast_projected_value, 0xFFEF5350.toInt())
                } else {
                     views.setTextColor(R.id.forecast_projected_value, 0xFFFFFFFF.toInt())
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}

class SavingsGoalWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_savings_goal)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val fmt = NumberFormat.getInstance(Locale("vi", "VN"))

                val goalName = prefs.getString("topGoalName", "—") ?: "—"
                val goalCurrent = prefs.getString("topGoalCurrent", "0")?.toFloatOrNull() ?: 0f
                val goalTarget = prefs.getString("topGoalTarget", "0")?.toFloatOrNull() ?: 0f
                val goalCount = prefs.getString("savingsGoalCount", "0")?.toIntOrNull() ?: 0
                val remaining = goalTarget - goalCurrent

                views.setTextViewText(R.id.savings_goal_name, goalName)
                views.setTextViewText(R.id.savings_current_value, "${fmt.format(goalCurrent.toLong())}₫")
                views.setTextViewText(R.id.savings_target_value, "/ ${fmt.format(goalTarget.toLong())}₫")
                views.setTextViewText(R.id.savings_goal_count, "$goalCount hũ")

                val progress = if (goalTarget > 0) ((goalCurrent / goalTarget) * 100).toInt() else 0
                views.setProgressBar(R.id.savings_progress, 100, progress.coerceIn(0, 100), false)
                views.setTextViewText(R.id.savings_percent, "${progress.coerceIn(0, 100)}%")

                if (remaining > 0) {
                    views.setTextViewText(R.id.savings_remaining, "Còn thiếu: ${fmt.format(remaining.toLong())}₫")
                } else {
                    views.setTextViewText(R.id.savings_remaining, "✓ Đã đạt!")
                    views.setTextColor(R.id.savings_remaining, 0xFF4CAF50.toInt())
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}

class QuickAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val fmt = NumberFormat.getInstance(Locale("vi", "VN"))

                val todaySpent = prefs.getString("todaySpent", "0")?.toFloatOrNull() ?: 0f
                val todayTxCount = prefs.getString("todayTxCount", "0")?.toIntOrNull() ?: 0

                views.setTextViewText(R.id.quick_today_spent, "${fmt.format(todaySpent.toLong())}₫")
                views.setTextViewText(R.id.quick_tx_count, "$todayTxCount giao dịch")

                // Open app on tap
                val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (intent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context, 0, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.quick_add_button, pendingIntent)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}

class HabitBreakerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_habit)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

                val habitName = prefs.getString("habitName", "Chưa có") ?: "Chưa có"
                val streak = prefs.getString("habitStreak", "0")?.toIntOrNull() ?: 0
                val status = prefs.getString("habitStatus", "Bắt đầu ngay!") ?: "Bắt đầu ngay!"

                views.setTextViewText(R.id.habit_name, habitName)
                views.setTextViewText(R.id.habit_streak_days, "$streak")
                views.setTextViewText(R.id.habit_status, status)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}

class RecurringWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_recurring)
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val fmt = NumberFormat.getInstance(Locale("vi", "VN"))

                val title = prefs.getString("recurringTitle", "Chưa có") ?: "Chưa có"
                val amount = prefs.getString("recurringAmount", "0")?.toFloatOrNull() ?: 0f
                val daysUntilDue = prefs.getString("recurringDays", "0")?.toIntOrNull() ?: 0

                views.setTextViewText(R.id.recurring_title, title)
                views.setTextViewText(R.id.recurring_amount, "${fmt.format(amount.toLong())}₫")

                val progress = if (daysUntilDue <= 0) 100 else (100 - (daysUntilDue * 3)).coerceIn(0, 100)
                views.setProgressBar(R.id.recurring_progress, 100, progress, false)

                if (daysUntilDue < 0) {
                    views.setTextViewText(R.id.recurring_status, "Đã quá hạn ${Math.abs(daysUntilDue)} ngày")
                    views.setTextColor(R.id.recurring_status, 0xFFEF5350.toInt()) // Red
                } else if (daysUntilDue == 0) {
                    views.setTextViewText(R.id.recurring_status, "Đến hạn hôm nay!")
                    views.setTextColor(R.id.recurring_status, 0xFFEF5350.toInt()) // Red
                } else {
                    views.setTextViewText(R.id.recurring_status, "Còn $daysUntilDue ngày")
                    views.setTextColor(R.id.recurring_status, 0xFFFFFFFF.toInt()) // White
                }

                // Open App Intent
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.recurring_title, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
