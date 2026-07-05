package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: total spent this month, trend vs last month, top category. */
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
                    WidgetCommon.str(widgetData, "month_label", "This month"),
                )
                setTextViewText(
                    R.id.month_spend,
                    WidgetCommon.str(widgetData, "month_spend", "₹0"),
                )
                val delta = WidgetCommon.str(widgetData, "month_delta", "")
                setTextViewText(R.id.month_delta, delta)
                setViewVisibility(
                    R.id.month_delta,
                    if (delta.isEmpty()) View.GONE else View.VISIBLE,
                )
                setTextViewText(
                    R.id.month_top,
                    WidgetCommon.str(widgetData, "month_top", "No spending yet"),
                )
                setTextViewText(R.id.updated, WidgetCommon.str(widgetData, "updated", ""))
                WidgetCommon.openApp(context, this, R.id.widget_root)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
