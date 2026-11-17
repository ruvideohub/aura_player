package com.example.aura_player

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle

object NotificationHelper {

    private fun pendingIntent(ctx: Context, action: String): PendingIntent {
        val i = Intent(ctx, MediaActionReceiver::class.java).apply { this.action = action }
        val flags = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(ctx, action.hashCode(), i, flags)
    }

    private fun openAppIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP }
        val flags = if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getActivity(ctx, 1001, i, flags)
    }

    fun build(ctx: Context, title: String, artist: String, isPlaying: Boolean, posMs: Long, durMs: Long): Notification {
        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playPauseLabel = if (isPlaying) "Пауза" else "Играть"

        // actions
        val prev = NotificationCompat.Action(android.R.drawable.ic_media_previous, "Назад", pendingIntent(ctx, "AURA_PREV"))
        val playPause = NotificationCompat.Action(playPauseIcon, playPauseLabel, pendingIntent(ctx, "AURA_TOGGLE"))
        val next = NotificationCompat.Action(android.R.drawable.ic_media_next, "Далее", pendingIntent(ctx, "AURA_NEXT"))
        val stop = NotificationCompat.Action(android.R.drawable.ic_menu_close_clear_cancel, "Стоп", pendingIntent(ctx, "AURA_STOP"))

        val builder = NotificationCompat.Builder(ctx, AudioService.CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title.ifEmpty { "AURA Player" })
            .setContentText(artist.ifEmpty { "Музыка" })
            .setSubText(if (durMs > 0) "${fmt(posMs)} / ${fmt(durMs)}" else null)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openAppIntent(ctx))
            .setDeleteIntent(pendingIntent(ctx, "AURA_STOP"))
            .addAction(prev)
            .addAction(playPause)
            .addAction(next)
            .addAction(stop)
            .setStyle(MediaStyle()
                .setShowActionsInCompactView(0,1,2)
                .setMediaSession(null))

        // цвет акцента
        try { builder.setColor(0xFFF59E0B.toInt()) } catch (_: Throwable) {}

        return builder.build()
    }

    fun fmt(ms: Long): String {
        val s = (ms/1000).toInt()
        val m = s/60; val sec = s%60
        val h = m/60
        return if (h>0) "%d:%02d:%02d".format(h, m%60, sec) else "%d:%02d".format(m, sec)
    }
}
