package com.example.aura_player

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.app.PendingIntent

/**
 * ForegroundService ТОЛЬКО для музыки.
 * Видео не заходит сюда — требование: фон только для аудио.
 * Держит процесс живым и показывает MediaStyle уведомление.
 */
class AudioService : Service() {
    companion object {
        const val CHANNEL_ID = "aura_music"
        const val NOTIF_ID = 1337
        const val ACTION_STOP = "AURA_STOP"
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            isRunning = false
            return START_NOT_STICKY
        }
        val title = intent?.getStringExtra("title") ?: "AURA Player"
        val artist = intent?.getStringExtra("artist") ?: ""
        val isPlaying = intent?.getBooleanExtra("isPlaying", true) ?: true
        val pos = intent?.getLongExtra("pos", 0L) ?: 0L
        val dur = intent?.getLongExtra("dur", 0L) ?: 0L

        // стартуем foreground
        val notif = NotificationHelper.build(this, title, artist, isPlaying, pos, dur)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIF_ID, notif, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIF_ID, notif)
        }
        // обновляем виджет
        AuraWidgetProvider.pushUpdate(this, title, artist, isPlaying, pos, dur)
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "AURA Music", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Управление музыкой AURA"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        }
    }
}
