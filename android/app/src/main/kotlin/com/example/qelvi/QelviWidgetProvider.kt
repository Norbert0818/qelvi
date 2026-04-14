package com.example.qelvi

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class QelviWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.qelvi_widget).apply {
                val status = widgetData.getString("status_text", "Ready to drive")
                setTextViewText(R.id.status_text, status)

                val startIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("qelvi://start")
                )
                setOnClickPendingIntent(R.id.btn_start, startIntent)

                val stopIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("qelvi://stop")
                )
                setOnClickPendingIntent(R.id.btn_stop, stopIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}