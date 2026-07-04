package com.example.settlement

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget with two shortcuts: a quick "Add expense" and a "Voice"
 * entry. Each opens the app with a deep-link URI that the Flutter side routes.
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
                setOnClickPendingIntent(
                    R.id.btn_add,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("settlement://add"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.btn_voice,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("settlement://voice"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
