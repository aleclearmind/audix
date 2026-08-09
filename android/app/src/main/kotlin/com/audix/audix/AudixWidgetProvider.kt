package com.audix.audix

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import com.ryanheise.audioservice.MediaButtonReceiver

/** A compact home-screen remote for the active Audix media session. */
class AudixWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val keyCode = when (intent.action) {
            ACTION_REWIND -> KeyEvent.KEYCODE_MEDIA_REWIND
            ACTION_TOGGLE -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            ACTION_FORWARD -> KeyEvent.KEYCODE_MEDIA_FAST_FORWARD
            else -> return
        }

        if (intent.action == ACTION_TOGGLE) {
            val prefs = preferences(context)
            prefs.edit().putBoolean(KEY_PLAYING, !prefs.getBoolean(KEY_PLAYING, false)).apply()
            updateAll(context)
        }
        sendMediaButton(context, keyCode)
    }

    companion object {
        private const val PREFERENCES = "audix_widget"
        private const val KEY_TITLE = "title"
        private const val KEY_SUBTITLE = "subtitle"
        private const val KEY_PLAYING = "playing"
        private const val ACTION_REWIND = "com.audix.audix.widget.REWIND"
        private const val ACTION_TOGGLE = "com.audix.audix.widget.TOGGLE"
        private const val ACTION_FORWARD = "com.audix.audix.widget.FORWARD"

        fun storeState(
            context: Context,
            title: String?,
            subtitle: String?,
            playing: Boolean,
        ) {
            preferences(context).edit()
                .putString(KEY_TITLE, title)
                .putString(KEY_SUBTITLE, subtitle)
                .putBoolean(KEY_PLAYING, playing)
                .apply()
            updateAll(context)
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, AudixWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            ids.forEach { id -> manager.updateAppWidget(id, buildViews(context)) }
        }

        private fun buildViews(context: Context): RemoteViews {
            val prefs = preferences(context)
            val title = prefs.getString(KEY_TITLE, null)
            val subtitle = prefs.getString(KEY_SUBTITLE, null)
            val playing = prefs.getBoolean(KEY_PLAYING, false)

            return RemoteViews(context.packageName, R.layout.audix_widget).apply {
                setTextViewText(
                    R.id.widget_title,
                    title ?: context.getString(R.string.widget_no_book),
                )
                setTextViewText(R.id.widget_subtitle, subtitle)
                setViewVisibility(
                    R.id.widget_subtitle,
                    if (subtitle.isNullOrBlank()) View.GONE else View.VISIBLE,
                )
                setImageViewResource(
                    R.id.widget_play_pause,
                    if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
                )
                setContentDescription(
                    R.id.widget_play_pause,
                    context.getString(if (playing) R.string.widget_pause else R.string.widget_play),
                )
                setOnClickPendingIntent(
                    R.id.widget_rewind,
                    controlIntent(context, ACTION_REWIND, 1),
                )
                setOnClickPendingIntent(
                    R.id.widget_play_pause,
                    controlIntent(context, ACTION_TOGGLE, 2),
                )
                setOnClickPendingIntent(
                    R.id.widget_forward,
                    controlIntent(context, ACTION_FORWARD, 3),
                )

                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    setOnClickPendingIntent(
                        R.id.widget_book,
                        PendingIntent.getActivity(context, 0, it, flags),
                    )
                }
            }
        }

        private fun preferences(context: Context) =
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

        private fun controlIntent(
            context: Context,
            action: String,
            requestCode: Int,
        ): PendingIntent {
            val intent = Intent(context, AudixWidgetProvider::class.java).setAction(action)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return PendingIntent.getBroadcast(context, requestCode, intent, flags)
        }

        private fun sendMediaButton(context: Context, keyCode: Int) {
            val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                component = ComponentName(context, MediaButtonReceiver::class.java)
                putExtra(
                    Intent.EXTRA_KEY_EVENT,
                    KeyEvent(KeyEvent.ACTION_DOWN, keyCode),
                )
                addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
            }
            context.sendBroadcast(intent)
        }
    }
}
