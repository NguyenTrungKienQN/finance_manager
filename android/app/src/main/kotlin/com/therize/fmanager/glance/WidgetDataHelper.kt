package com.therize.fmanager.glance

import java.text.NumberFormat
import java.util.Locale

object WidgetDataHelper {
    fun formatCurrency(amount: Double): String {
        val formatter = NumberFormat.getNumberInstance(Locale("vi", "VN"))
        formatter.maximumFractionDigits = 0
        return "${formatter.format(amount)}₫"
    }
}
