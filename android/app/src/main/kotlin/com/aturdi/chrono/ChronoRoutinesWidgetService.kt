package com.aturdi.chrono

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import es.antonborri.home_widget.HomeWidgetPlugin
import android.view.View
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri

class ChronoRoutinesWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ChronoRoutinesRemoteViewsFactory(this.applicationContext)
    }
}

class ChronoRoutinesRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var routinesList = ArrayList<JSONObject>()

    override fun onCreate() {
        // Initial data load
    }

    override fun onDataSetChanged() {
        // Refresh data from SharedPreferences
        val widgetData = HomeWidgetPlugin.getData(context)
        val routinesDataString = widgetData.getString("routines_data", "[]") ?: "[]"
        try {
            val jsonArray = JSONArray(routinesDataString)
            routinesList.clear()
            
            // Filter out completed routines
            for (i in 0 until jsonArray.length()) {
                val routine = jsonArray.getJSONObject(i)
                val isDone = routine.optBoolean("isDone", false)
                routinesList.add(routine)
            }
        } catch (e: Exception) {
            routinesList.clear()
        }
    }

    override fun onDestroy() {
        routinesList.clear()
    }

    override fun getCount(): Int {
        return routinesList.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= routinesList.size) {
            return RemoteViews(context.packageName, R.layout.widget_routine_item)
        }

        val views = RemoteViews(context.packageName, R.layout.widget_routine_item)
        
        try {
            val routine = routinesList[position]
            val routineId = routine.getInt("id")
            val name = routine.getString("name")
            val time = routine.getString("time")
            val isDone = routine.getBoolean("isDone")
            val streak = routine.getInt("streak")
            val showStreak = routine.getBoolean("showStreak")

            // Set texts
            views.setTextViewText(R.id.routine_name, name)
            views.setTextViewText(R.id.routine_time, time)

            // Handle Done state (Strikethrough and text color)
            if (isDone) {
                views.setInt(R.id.routine_name, "setPaintFlags", Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                views.setTextColor(R.id.routine_name, Color.parseColor("#7E8287")) // Greyed out
                
                // Set check icon
                views.setImageViewResource(R.id.routine_checkbox_icon, R.drawable.ic_widget_check)
            } else {
                views.setInt(R.id.routine_name, "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
                views.setTextColor(R.id.routine_name, Color.WHITE)
                
                // Set empty square icon (checkbox style)
                views.setImageViewResource(R.id.routine_checkbox_icon, R.drawable.ic_widget_checkbox_off)
            }

            // Handle Streak
            if (showStreak && streak > 0) {
                views.setViewVisibility(R.id.routine_streak_container, View.VISIBLE)
                views.setViewVisibility(R.id.routine_streak, View.VISIBLE)
                views.setTextViewText(R.id.routine_streak, "🔥$streak")
            } else {
                views.setViewVisibility(R.id.routine_streak_container, View.GONE)
            }

            // FillInIntent for Click Handling
            // We set the DATA of the intent to the specific URI
            // This gets merged with the template intent
            val fillInIntent = Intent().apply {
                data = Uri.parse("chrono://toggle_routine?id=$routineId")
            }
            
            // Set it on the root view of the item to capture all clicks
            views.setOnClickFillInIntent(R.id.widget_routine_item, fillInIntent)

        } catch (e: Exception) {
            e.printStackTrace()
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return try {
            routinesList[position].getInt("id").toLong()
        } catch (e: Exception) {
            position.toLong()
        }
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
