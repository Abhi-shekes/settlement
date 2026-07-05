package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Finance Overview widget — the adaptive, do-it-all widget.
 *
 * Compact (small): net worth + monthly spend. Expanded (large): adds the top
 * category, up to two budget progress rows and Add / Assistant quick actions.
 * Resizes responsively like [BudgetWidget].
 */
class OverviewWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                RemoteViews(
                    mapOf(
                        SizeF(180f, 110f) to build(context, widgetData, expanded = false),
                        SizeF(250f, WidgetCommon.EXPAND_HEIGHT_DP.toFloat()) to
                            build(context, widgetData, expanded = true),
                    ),
                )
            } else {
                build(context, widgetData, expanded = isTall(appWidgetManager.getAppWidgetOptions(widgetId)))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        appWidgetManager.updateAppWidget(
            appWidgetId,
            build(context, WidgetCommon.prefs(context), expanded = isTall(newOptions)),
        )
    }

    private fun isTall(options: Bundle): Boolean =
        options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) >=
            WidgetCommon.EXPAND_HEIGHT_DP

    private fun build(context: Context, data: SharedPreferences, expanded: Boolean): RemoteViews {
        val layout = if (expanded) R.layout.widget_overview_expanded else R.layout.widget_overview
        return RemoteViews(context.packageName, layout).apply {
            setTextViewText(R.id.net_worth, WidgetCommon.str(data, "net_worth", "₹0"))
            setTextViewText(R.id.month_spend, WidgetCommon.str(data, "month_spend", "₹0"))
            setTextViewText(R.id.updated, WidgetCommon.str(data, "updated", ""))

            if (expanded) {
                val delta = WidgetCommon.str(data, "month_delta", "")
                setTextViewText(R.id.month_delta, delta)
                setViewVisibility(R.id.month_delta, if (delta.isEmpty()) View.GONE else View.VISIBLE)

                val top = WidgetCommon.str(data, "month_top", "")
                setTextViewText(R.id.month_top, top)
                setViewVisibility(R.id.month_top, if (top.isEmpty()) View.GONE else View.VISIBLE)

                WidgetCommon.bindBudgets(context, this, data, maxRows = 2)
                WidgetCommon.openApp(context, this, R.id.btn_add, host = "add")
                WidgetCommon.openApp(context, this, R.id.btn_assistant, host = "assistant")
            }

            WidgetCommon.openApp(context, this, R.id.widget_root)
        }
    }
}
