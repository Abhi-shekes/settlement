package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: total spent in the current month + top category. */
class MonthSpendWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_month_spend).apply {
                setTextViewText(
                    R.id.month_label,
                    widgetData.getString("month_label", "This month") ?: "This month",
                )
                setTextViewText(
                    R.id.month_spend,
                    widgetData.getString("month_spend", "₹0") ?: "₹0",
                )
                setTextViewText(
                    R.id.month_top,
                    widgetData.getString("month_top", "No spending yet") ?: "No spending yet",
                )
                setTextViewText(R.id.updated, widgetData.getString("updated", "") ?: "")
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
