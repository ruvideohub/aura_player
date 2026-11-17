package com.example.aura_player

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class AuraWidgetProvider : AppWidgetProvider() {

    companion object {
        // кэш последних данных чтобы обновлять при onUpdate
        var lastTitle = "AURA Player"
        var lastArtist = "Нет трека"
        var lastIsPlaying = false
        var lastPos = 0L
        var lastDur = 0L

        fun pushUpdate(ctx: Context, title: String, artist: String, isPlaying: Boolean, pos: Long, dur: Long) {
            lastTitle = title
            lastArtist = artist
            lastIsPlaying = isPlaying
            lastPos = pos
            lastDur = dur
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, AuraWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                val intent = Intent(ctx, AuraWidgetProvider::class.java).apply { action = AppWidgetManager.ACTION_APPWIDGET_UPDATE; putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids) }
                ctx.sendBroadcast(intent)
            }
            // также обновим напрямую
            try { updateAll(ctx) } catch (_: Throwable) {}
        }

        fun updateAll(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, AuraWidgetProvider::class.java))
            for (id in ids) {
                val views = RemoteViews(ctx.packageName, R.layout.widget_aura)
                views.setTextViewText(R.id.widget_title, lastTitle)
                views.setTextViewText(R.id.widget_artist, lastArtist.ifEmpty { "AURA • Музыка" })
                views.setTextViewText(R.id.widget_pos, NotificationHelper.fmt(lastPos))
                views.setTextViewText(R.id.widget_dur, NotificationHelper.fmt(lastDur))
                val prog = if (lastDur > 0) ((lastPos * 1000 / lastDur).toInt().coerceIn(0, 1000)) else 0
                views.setProgressBar(R.id.widget_progress, 1000, prog, false)
                views.setImageViewResource(R.id.widget_play, if (lastIsPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)

                fun pi(action: String): PendingIntent {
                    val i = Intent(ctx, MediaActionReceiver::class.java).apply { this.action = action }
                    val f = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
                    return PendingIntent.getBroadcast(ctx, action.hashCode()+id, i, f)
                }
                fun openPi(): PendingIntent {
                    val i = Intent(ctx, MainActivity::class.java)
                    val f = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
                    return PendingIntent.getActivity(ctx, 2000+id, i, f)
                }
                views.setOnClickPendingIntent(R.id.widget_prev, pi("AURA_PREV"))
                views.setOnClickPendingIntent(R.id.widget_play, pi("AURA_TOGGLE"))
                views.setOnClickPendingIntent(R.id.widget_next, pi("AURA_NEXT"))
                views.setOnClickPendingIntent(R.id.widget_open, openPi())
                views.setOnClickPendingIntent(R.id.widget_cover, openPi())
                mgr.updateAppWidget(id, views)
            }
        }
    }

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) {
            val views = RemoteViews(ctx.packageName, R.layout.widget_aura)
            views.setTextViewText(R.id.widget_title, lastTitle)
            views.setTextViewText(R.id.widget_artist, lastArtist)
            views.setTextViewText(R.id.widget_pos, NotificationHelper.fmt(lastPos))
            views.setTextViewText(R.id.widget_dur, NotificationHelper.fmt(lastDur))
            val prog = if (lastDur > 0) ((lastPos * 1000 / lastDur).toInt().coerceIn(0, 1000)) else 0
            views.setProgressBar(R.id.widget_progress, 1000, prog, false)
            views.setImageViewResource(R.id.widget_play, if (lastIsPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play)
            fun pi(a: String): PendingIntent {
                val i = Intent(ctx, MediaActionReceiver::class.java).apply { action = a }
                val f = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
                return PendingIntent.getBroadcast(ctx, a.hashCode()+id, i, f)
            }
            fun openPi(): PendingIntent {
                val i = Intent(ctx, MainActivity::class.java)
                val f = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
                return PendingIntent.getActivity(ctx, 3000+id, i, f)
            }
            views.setOnClickPendingIntent(R.id.widget_prev, pi("AURA_PREV"))
            views.setOnClickPendingIntent(R.id.widget_play, pi("AURA_TOGGLE"))
            views.setOnClickPendingIntent(R.id.widget_next, pi("AURA_NEXT"))
            views.setOnClickPendingIntent(R.id.widget_open, openPi())
            views.setOnClickPendingIntent(R.id.widget_cover, openPi())
            mgr.updateAppWidget(id, views)
        }
    }
}

private fun String.ifEmpty(fallback: String): String = if (this.isEmpty()) fallback else this
