package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
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
                    WidgetCommon.str(widgetData, "net_worth", "₹0"),
                )
                setTextViewText(
                    R.id.accounts_sub,
                    WidgetCommon.str(widgetData, "accounts_sub", "No accounts yet"),
                )
                val top = WidgetCommon.str(widgetData, "account_top", "")
                setTextViewText(R.id.account_top, top)
                setViewVisibility(
                    R.id.account_top,
                    if (top.isEmpty()) View.GONE else View.VISIBLE,
                )
                setTextViewText(R.id.updated, WidgetCommon.str(widgetData, "updated", ""))
                WidgetCommon.openApp(context, this, R.id.widget_root)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
