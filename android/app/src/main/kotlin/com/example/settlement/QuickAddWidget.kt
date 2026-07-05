package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget with three shortcuts — Add expense, Voice entry and AI
 * Assistant — plus a refresh tap. Each opens the app with a deep-link URI that
 * the Flutter side routes (see home_screen.dart `_routeWidgetUri`).
 */
class QuickAddWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add).apply {
                WidgetCommon.openApp(context, this, R.id.btn_add, host = "add")
                WidgetCommon.openApp(context, this, R.id.btn_voice, host = "voice")
                WidgetCommon.openApp(context, this, R.id.btn_assistant, host = "assistant")
                WidgetCommon.openApp(context, this, R.id.btn_refresh, host = "refresh")
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
