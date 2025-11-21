package com.aturdi.chrono

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

// Base class for widget providers
abstract class BaseChronoWidgetProvider : AppWidgetProvider() {
    abstract fun getLayoutId(): Int
    abstract fun isLargeWidget(): Boolean

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun getPendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
            this.data = Uri.parse(action)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val hasInsight = widgetData.getBoolean("has_insight", false)
        val title = widgetData.getString("insight_title", "") ?: ""
        val body = widgetData.getString("insight_body", "") ?: ""
        val placeholderText = widgetData.getString("placeholder_text", "No insights yet") ?: "No insights yet"

        val views = RemoteViews(context.packageName, getLayoutId())

        // Update content based on widget type
        when (getLayoutId()) {
            R.layout.chrono_widget_small -> {
                if (hasInsight && title.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_title, title)
                } else {
                    views.setTextViewText(R.id.widget_title, "Chrono")
                }
                views.setOnClickPendingIntent(
                    R.id.widget_button_create_note,
                    getPendingIntent(context, "chrono://create_note", 1)
                )
            }
            R.layout.chrono_widget_medium -> {
                if (hasInsight && title.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_title, title)
                    views.setTextViewText(R.id.widget_body, body)
                } else {
                    views.setTextViewText(R.id.widget_title, "Chrono")
                    views.setTextViewText(R.id.widget_body, placeholderText)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_button_create_note,
                    getPendingIntent(context, "chrono://create_note", 2)
                )
            }
            R.layout.chrono_widget_large -> {
                if (hasInsight && title.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_title, title)
                    views.setTextViewText(R.id.widget_body, body)
                } else {
                    views.setTextViewText(R.id.widget_title, "Chrono")
                    views.setTextViewText(R.id.widget_body, placeholderText)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_button_create_note,
                    getPendingIntent(context, "chrono://create_note", 3)
                )
                views.setOnClickPendingIntent(
                    R.id.widget_button_open_insight,
                    getPendingIntent(context, "chrono://open_insight", 4)
                )
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

// Small widget provider
class ChronoSmallWidgetProvider : BaseChronoWidgetProvider() {
    override fun getLayoutId() = R.layout.chrono_widget_small
    override fun isLargeWidget() = false
}

// Medium widget provider
class ChronoMediumWidgetProvider : BaseChronoWidgetProvider() {
    override fun getLayoutId() = R.layout.chrono_widget_medium
    override fun isLargeWidget() = false
}

// Large widget provider
class ChronoLargeWidgetProvider : BaseChronoWidgetProvider() {
    override fun getLayoutId() = R.layout.chrono_widget_large
    override fun isLargeWidget() = true
}
