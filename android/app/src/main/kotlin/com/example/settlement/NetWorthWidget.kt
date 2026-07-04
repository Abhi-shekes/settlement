package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: total balance across all accounts (net worth). */
class NetWorthWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_net_worth).apply {
                setTextViewText(
                    R.id.net_worth,
                    widgetData.getString("net_worth", "₹0") ?: "₹0",
                )
                setTextViewText(
                    R.id.accounts_sub,
                    widgetData.getString("accounts_sub", "No accounts yet") ?: "No accounts yet",
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
