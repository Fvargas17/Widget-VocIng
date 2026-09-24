package com.example.widget_vocing

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class VocabularyAppWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val isCompact = widgetData.getBoolean("widget_compact_mode", false)
            val layoutId = if (isCompact) {
                R.layout.vocabulary_widget_layout_compact
            } else {
                R.layout.vocabulary_widget_layout
            }
            val views = RemoteViews(context.packageName, layoutId).apply {
                val isEmpty = widgetData.getBoolean("widget_empty", true)
                if (isEmpty) {
                    setTextViewText(R.id.widget_word, "¡Todo aprendido!")
                    setTextViewText(R.id.widget_pronunciation, "")
                    setTextViewText(R.id.widget_example, "")
                } else {
                    setTextViewText(R.id.widget_word, widgetData.getString("widget_word", ""))
                    setTextViewText(
                        R.id.widget_pronunciation,
                        "/" + widgetData.getString("widget_pronunciation", "") + "/"
                    )
                    setTextViewText(R.id.widget_example, widgetData.getString("widget_example", ""))
                }

                // Tap en el cuerpo del widget abre la app.
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                )

                // Los tres botones disparan el callback Dart en background
                // (ver backgroundCallback en home_widget_callback.dart) sin
                // necesidad de abrir la app.
                setOnClickPendingIntent(
                    R.id.widget_btn_previous,
                    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("vocabwidget://previous"))
                )
                setOnClickPendingIntent(
                    R.id.widget_btn_next,
                    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("vocabwidget://next"))
                )
                setOnClickPendingIntent(
                    R.id.widget_btn_learned,
                    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("vocabwidget://learned"))
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
