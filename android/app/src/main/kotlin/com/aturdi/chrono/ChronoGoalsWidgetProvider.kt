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
import kotlin.math.min

class ChronoGoalsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun getPendingIntent(context: Context, action: String, goalId: String? = null, requestCode: Int): PendingIntent {
        val uri = if (goalId != null) {
            Uri.parse("chrono://$action?id=$goalId")
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
        val goalsDataString = widgetData.getString("goals_data", "[]") ?: "[]"

        val views = RemoteViews(context.packageName, R.layout.chrono_goals_widget)

        // Parse goals data
        try {
            val goalsArray = JSONArray(goalsDataString)
            val goalSlots = listOf(R.id.goal_1, R.id.goal_2, R.id.goal_3, R.id.goal_4)

            if (goalsArray.length() == 0) {
                // Show "no goals" message
                views.setViewVisibility(R.id.widget_no_goals, android.view.View.VISIBLE)
                // Hide all goal slots
                goalSlots.forEach { views.setViewVisibility(it, android.view.View.GONE) }
            } else {
                // Hide "no goals" message
                views.setViewVisibility(R.id.widget_no_goals, android.view.View.GONE)

                // Show up to 4 goals
                for (i in 0 until min(4, goalsArray.length())) {
                    val goal = goalsArray.getJSONObject(i)
                    val goalId = goal.getInt("id")
                    val title = goal.getString("title")
                    val progress = goal.getInt("progress")
                    val timeSpent = goal.getString("timeSpent")
                    val goalTime = goal.getString("goalTime")
                    val isRunning = goal.getBoolean("isRunning")

                    val slotId = goalSlots[i]
                    val index = i + 1

                    // Show this goal slot
                    views.setViewVisibility(slotId, android.view.View.VISIBLE)

                    // Update goal info with unique IDs
                    views.setTextViewText(getGoalChildId(index, "title"), title)
                    
                    // Update subtitle based on running state
                    val subtitleText = if (isRunning) {
                        "Running: $timeSpent"
                    } else {
                        "Time spent: $timeSpent / $goalTime"
                    }
                    views.setTextViewText(getGoalChildId(index, "time_spent"), subtitleText)
                    
                    // Set subtitle color (Green if running, Grey if not)
                    val subtitleColor = if (isRunning) android.graphics.Color.GREEN else android.graphics.Color.parseColor("#C3C5C9")
                    views.setTextColor(getGoalChildId(index, "time_spent"), subtitleColor)

                    // Progress Bar
                    views.setProgressBar(getGoalChildId(index, "progress"), 100, progress, false)
                    
                    // Percentage Text
                    views.setTextViewText(getGoalChildId(index, "percentage"), "$progress%")

                    // Update play/stop button
                    val playButtonId = getGoalChildId(index, "play_button")
                    if (isRunning) {
                        views.setImageViewResource(playButtonId, android.R.drawable.ic_media_pause)
                        views.setOnClickPendingIntent(
                            playButtonId,
                            getPendingIntent(context, "stop_goal", goalId.toString(), 300 + i)
                        )
                    } else {
                        views.setImageViewResource(playButtonId, android.R.drawable.ic_media_play)
                        views.setOnClickPendingIntent(
                            playButtonId,
                            getPendingIntent(context, "start_goal", goalId.toString(), 400 + i)
                        )
                    }
                }

                // Hide unused slots
                for (i in goalsArray.length() until 4) {
                    views.setViewVisibility(goalSlots[i], android.view.View.GONE)
                }
            }
        } catch (e: Exception) {
            views.setViewVisibility(R.id.widget_no_goals, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_no_goals, "Error loading goals: ${e.message}")
        }

        // Set click handler for open goals button
        views.setOnClickPendingIntent(
            R.id.widget_button_open_goals,
            getPendingIntent(context, "open_goals", null, 202)
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun getGoalChildId(index: Int, childName: String): Int {
        return when (index) {
            1 -> when (childName) {
                "title" -> R.id.goal_title_1
                "progress" -> R.id.goal_progress_1
                "time_spent" -> R.id.goal_time_spent_1
                "percentage" -> R.id.goal_percentage_1
                "play_button" -> R.id.goal_play_button_1
                else -> 0
            }
            2 -> when (childName) {
                "title" -> R.id.goal_title_2
                "progress" -> R.id.goal_progress_2
                "time_spent" -> R.id.goal_time_spent_2
                "percentage" -> R.id.goal_percentage_2
                "play_button" -> R.id.goal_play_button_2
                else -> 0
            }
            3 -> when (childName) {
                "title" -> R.id.goal_title_3
                "progress" -> R.id.goal_progress_3
                "time_spent" -> R.id.goal_time_spent_3
                "percentage" -> R.id.goal_percentage_3
                "play_button" -> R.id.goal_play_button_3
                else -> 0
            }
            4 -> when (childName) {
                "title" -> R.id.goal_title_4
                "progress" -> R.id.goal_progress_4
                "time_spent" -> R.id.goal_time_spent_4
                "percentage" -> R.id.goal_percentage_4
                "play_button" -> R.id.goal_play_button_4
                else -> 0
            }
            else -> 0
        }
    }
}
