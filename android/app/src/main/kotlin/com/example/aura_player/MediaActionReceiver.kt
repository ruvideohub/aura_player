package com.example.aura_player

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Принимает нажатия с уведомления и виджета.
 * Пересылает в MainActivity через явный intent, а MainActivity пробрасывает в Flutter.
 */
class MediaActionReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val action = intent.action ?: return
        val flutterIntent = Intent(ctx, MainActivity::class.java).apply {
            this.action = action
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        // На Android 10+ нужен Foreground для старта активити из фона? Используем обычный старт, но если экран выкл — всё равно сработает через сервис
        try {
            ctx.startActivity(flutterIntent)
        } catch (_: Throwable) {
            // fallback: отправим broadcast в MainActivity если уже запущена
            val b = Intent("AURA_MEDIA_ACTION").apply { putExtra("action", action); setPackage(ctx.packageName) }
            ctx.sendBroadcast(b)
        }
        // обновим сервис если нужно
        if (action == "AURA_STOP") {
            val stopService = Intent(ctx, AudioService::class.java).apply { this.action = AudioService.ACTION_STOP }
            try { ctx.startService(stopService) } catch (_: Throwable) {}
            if (Build.VERSION.SDK_INT >= 26) try { ctx.startForegroundService(stopService) } catch (_: Throwable) {}
        }
    }
}
