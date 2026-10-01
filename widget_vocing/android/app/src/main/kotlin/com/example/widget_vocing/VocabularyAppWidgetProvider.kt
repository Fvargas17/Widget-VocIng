package com.example.widget_vocing

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Colores del preset "Bosque Luminoso" (el default de la app) — se usan solo
// si `VocabularyStateService._syncWidget` todavía no corrió ni una vez (p.
// ej. justo tras instalar y agregar el widget sin haber abierto la app).
private const val DEFAULT_COLOR_CARD = "#FFF4FBFA"
private const val DEFAULT_COLOR_BUTTON = "#FF0E9E97"
private const val DEFAULT_COLOR_TEXT = "#FF0B2624"
private const val DEFAULT_COLOR_TEXT_SECONDARY = "#FF4C7570"

// Estado vacío en el idioma del curso por defecto (Español → Inglés). El texto
// real llega desde Dart en "widget_empty_text", porque solo ahí se sabe qué
// curso —y por lo tanto qué idioma de interfaz— está activo; este default
// cubre el caso de agregar el widget sin haber abierto nunca la app.
private const val DEFAULT_EMPTY_TEXT = "¡Todo aprendido!"

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
                    setTextViewText(
                        R.id.widget_word,
                        widgetData.getString("widget_empty_text", DEFAULT_EMPTY_TEXT)
                    )
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

                val colorCard = parseWidgetColor(widgetData, "widget_color_card", DEFAULT_COLOR_CARD)
                val colorButton = parseWidgetColor(widgetData, "widget_color_button", DEFAULT_COLOR_BUTTON)
                val colorText = parseWidgetColor(widgetData, "widget_color_text", DEFAULT_COLOR_TEXT)
                val colorTextSecondary = parseWidgetColor(
                    widgetData,
                    "widget_color_text_secondary",
                    DEFAULT_COLOR_TEXT_SECONDARY
                )

                tintBackground(R.id.widget_root, colorCard)
                tintBackground(R.id.widget_btn_previous, colorButton)
                tintBackground(R.id.widget_btn_next, colorButton)
                tintBackground(R.id.widget_btn_learned, colorButton)
                setTextColor(R.id.widget_word, colorText)
                setTextColor(R.id.widget_example, colorText)
                setTextColor(R.id.widget_pronunciation, colorTextSecondary)

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

    /**
     * Lee un color guardado por `VocabularyStateService._colorToHex()` como
     * string `#AARRGGBB`. Atrapa `ClassCastException` porque una instalación
     * que traiga datos de una versión anterior (cuando estos colores se
     * guardaban como `Int`/`Long`, ambiguos por cómo el codec de Flutter
     * serializa según el valor) podría tener la clave guardada con otro tipo;
     * en ese caso cae al color por defecto y se autocorrige en cuanto la app
     * vuelva a sincronizar el widget (`putString` reemplaza la entrada
     * completa, sin importar el tipo que tenía antes).
     */
    private fun parseWidgetColor(widgetData: SharedPreferences, key: String, fallbackHex: String): Int {
        val hex = try {
            widgetData.getString(key, fallbackHex)
        } catch (_: ClassCastException) {
            fallbackHex
        }
        return try {
            Color.parseColor(hex)
        } catch (_: IllegalArgumentException) {
            Color.parseColor(fallbackHex)
        }
    }

    /**
     * Colorea el fondo de [viewId] con [color] sin perder las esquinas
     * redondeadas del `shape` declarado en el layout (`widget_card_background`
     * / `widget_button_background`): `setBackgroundTintList` tiñe el drawable
     * existente en vez de reemplazarlo. Solo existe en `RemoteViews` desde
     * API 31 — en versiones anteriores se degrada a `setBackgroundColor`,
     * que sí sincroniza el color pero pierde el radio de esquina.
     */
    private fun RemoteViews.tintBackground(viewId: Int, color: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setColorStateList(viewId, "setBackgroundTintList", ColorStateList.valueOf(color))
        } else {
            setInt(viewId, "setBackgroundColor", color)
        }
    }
}
