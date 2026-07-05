package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget: month-to-date progress bars against category budgets.
 *
 * Responsive: on Android 12+ the launcher swaps between the compact (2-row) and
 * expanded (4-row) layouts as the widget is resized, via the RemoteViews size
 * map. On older versions we pick the layout from the current widget height and
 * re-pick in onAppWidgetOptionsChanged when the user resizes.
 */
class BudgetWidget : HomeWidgetProvider() {
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
                val opts = appWidgetManager.getAppWidgetOptions(widgetId)
                build(context, widgetData, expanded = isTall(opts))
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
        val views = build(context, WidgetCommon.prefs(context), expanded = isTall(newOptions))
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun isTall(options: Bundle): Boolean =
        options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) >=
            WidgetCommon.EXPAND_HEIGHT_DP

    private fun build(context: Context, data: SharedPreferences, expanded: Boolean): RemoteViews {
        val layout = if (expanded) R.layout.widget_budget_expanded else R.layout.widget_budget
        return RemoteViews(context.packageName, layout).apply {
            WidgetCommon.bindBudgets(context, this, data, maxRows = if (expanded) 4 else 2)
            WidgetCommon.openApp(context, this, R.id.widget_root)
        }
    }
}
