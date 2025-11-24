package com.aturdi.chrono

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import org.json.JSONArray

class ChronoRoutinesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun getPendingIntent(context: Context, action: String, routineId: String? = null, requestCode: Int): PendingIntent {
        val uri = if (routineId != null) {
            Uri.parse("chrono://$action?id=$routineId")
        } else {
            Uri.parse("chrono://$action")
        }

        if (action.startsWith("open_")) {
            val intent = Intent(context, MainActivity::class.java).apply {
                this.action = action
                this.data = uri
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        return HomeWidgetBackgroundIntent.getBroadcast(context, uri)
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val routinesDataString = widgetData.getString("routines_data", "[]") ?: "[]"
        val routinesCount = widgetData.getInt("routines_count", 0)
        val completedCount = widgetData.getInt("completed_count", 0)

        val views = RemoteViews(context.packageName, R.layout.chrono_routines_widget)

        // Update stats
        views.setTextViewText(R.id.widget_routines_stats, "$completedCount/$routinesCount")

        // Check if we have routines
        try {
            val routinesArray = JSONArray(routinesDataString)
            if (routinesArray.length() == 0) {
                views.setViewVisibility(R.id.widget_no_routines, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_routines_list, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_no_routines, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_routines_list, android.view.View.VISIBLE)
                
                // Set up the ListView adapter
                val intent = Intent(context, ChronoRoutinesWidgetService::class.java)
                intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                intent.data = Uri.parse(intent.toUri(Intent.URI_INTENT_SCHEME))
                views.setRemoteAdapter(R.id.widget_routines_list, intent)
                
                // Set template for click handling on list items
                // IMPORTANT: We use a base intent without ID here.
                // The collection items will fill in the details using fillInIntent.
                // We point to HomeWidgetBackgroundReceiver.
                val backgroundIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java)
                backgroundIntent.action = "es.antonborri.home_widget.action.BACKGROUND"
                
                val clickIntentTemplate = PendingIntent.getBroadcast(
                    context, 
                    0, 
                    backgroundIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                
                views.setPendingIntentTemplate(R.id.widget_routines_list, clickIntentTemplate)
            }
        } catch (e: Exception) {
             views.setViewVisibility(R.id.widget_no_routines, android.view.View.VISIBLE)
             views.setTextViewText(R.id.widget_no_routines, "Error: ${e.message}")
        }

        // Set click handler for open routines button
        views.setOnClickPendingIntent(
            R.id.widget_button_open_routines,
            getPendingIntent(context, "open_routines", null, 100)
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_routines_list)
    }
}
