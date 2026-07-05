package com.example.settlement

import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Shared rendering helpers for the Settlement home-screen widgets.
 *
 * All widget data is pushed from Flutter (see HomeWidgetService) into the
 * home_widget SharedPreferences file and read back here as strings, so there is
 * a single source of truth and no int/String type mismatches.
 */
object WidgetCommon {
    /** home_widget's fixed Android SharedPreferences file. */
    const val PREFS = "HomeWidgetPreferences"

    /** Below this many dp of height a resizable widget uses its compact layout. */
    const val EXPAND_HEIGHT_DP = 180

    private val rowIds = intArrayOf(
        R.id.budget_0_row, R.id.budget_1_row, R.id.budget_2_row, R.id.budget_3_row,
    )
    private val labelIds = intArrayOf(
        R.id.budget_0_label, R.id.budget_1_label, R.id.budget_2_label, R.id.budget_3_label,
    )
    private val amountIds = intArrayOf(
        R.id.budget_0_amount, R.id.budget_1_amount, R.id.budget_2_amount, R.id.budget_3_amount,
    )
    private val barIds = intArrayOf(
        R.id.budget_0_bar, R.id.budget_1_bar, R.id.budget_2_bar, R.id.budget_3_bar,
    )

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun str(data: SharedPreferences, key: String, def: String): String =
        data.getString(key, def) ?: def

    /** Opens the app, optionally deep-linking to `settlement://<host>`. */
    fun openApp(context: Context, views: RemoteViews, viewId: Int, host: String? = null) {
        val uri = host?.let { Uri.parse("settlement://$it") }
        views.setOnClickPendingIntent(
            viewId,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri),
        )
    }

    /**
     * Binds up to [maxRows] budget progress rows (label, spent / limit, %,
     * colored bar). Missing view ids in a given layout are ignored by
     * RemoteViews, so the same call works for the compact, expanded and overview
     * layouts. Any budgets beyond [maxRows] are summarised as "+N more".
     */
    fun bindBudgets(context: Context, views: RemoteViews, data: SharedPreferences, maxRows: Int) {
        val count = str(data, "budget_count", "0").toIntOrNull() ?: 0
        views.setViewVisibility(R.id.budget_empty, if (count == 0) View.VISIBLE else View.GONE)

        val shown = minOf(count, maxRows, rowIds.size)
        for (i in rowIds.indices) {
            if (i < shown) {
                views.setViewVisibility(rowIds[i], View.VISIBLE)
                views.setTextViewText(labelIds[i], str(data, "budget_${i}_label", ""))
                views.setTextViewText(amountIds[i], str(data, "budget_${i}_amount", ""))
                val pct = (str(data, "budget_${i}_pct", "0").toIntOrNull() ?: 0).coerceIn(0, 100)
                views.setProgressBar(barIds[i], 100, pct, false)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Tint the bar green / amber / red by budget state. Guarded to
                    // API 31+, where setColorStateList + getColor are available.
                    views.setColorStateList(
                        barIds[i],
                        "setProgressTintList",
                        ColorStateList.valueOf(
                            progressColor(context, str(data, "budget_${i}_state", "ok")),
                        ),
                    )
                }
            } else {
                views.setViewVisibility(rowIds[i], View.GONE)
            }
        }

        val more = count - shown
        views.setViewVisibility(R.id.budget_more, if (more > 0) View.VISIBLE else View.GONE)
        if (more > 0) views.setTextViewText(R.id.budget_more, "+$more more")
    }

    private fun progressColor(context: Context, state: String): Int {
        val res = when (state) {
            "over" -> R.color.widget_progress_over
            "warn" -> R.color.widget_progress_warn
            else -> R.color.widget_progress_ok
        }
        return context.getColor(res)
    }
}
