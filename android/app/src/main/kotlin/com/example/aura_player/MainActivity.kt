package com.example.aura_player

import android.app.PictureInPictureParams
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * AURA Player — точка входа Android.
 * Регистрирует Platform Channel «aura.player/native», через который
 * Dart-слой обращается к Kotlin.
 */
class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var lastTitle: String = ""
    private var lastArtist: String = ""
    private var lastIsPlaying: Boolean = false
    private var lastPos: Long = 0L
    private var lastDur: Long = 0L
    private var pendingAction: String? = null
    private var pendingOpenPath: String? = null

    private val mediaActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            val a = intent?.getStringExtra("action") ?: return
            handleMediaAction(a)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aura.player/native")
        channel = ch

        // Реальный визуализатор — EventChannel
        try {
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, "aura.player/visualizer")
                .setStreamHandler(VisualizerHelper)
        } catch (_: Throwable) {}

        // Ловим broadcast от виджета/уведомления когда активити не в топе
        try {
            val f = IntentFilter("AURA_MEDIA_ACTION")
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(mediaActionReceiver, f, Context.RECEIVER_NOT_EXPORTED)
            else registerReceiver(mediaActionReceiver, f)
        } catch (_: Throwable) {}

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "scanMedia" -> MediaStoreScanner.scan(applicationContext, result)
                "albumArt" -> {
                    val path = call.argument<String>("path")
                    if (path != null) MediaStoreScanner.albumArt(applicationContext, path, result) else result.success(null)
                }
                "eqSetEnabled" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    SystemEqualizer.setEnabled(on, result)
                }
                "eqSetGains" -> {
                    val gains = call.argument<List<Double>>("gains") ?: emptyList()
                    SystemEqualizer.setGains(gains, result)
                }
                "eqSetBass" -> {
                    val strength = call.argument<Number>("strength")?.toInt() ?: 0
                    SystemEqualizer.setBassBoost(strength, result)
                }
                "getBrightness" -> {
                    val win = activity?.window
                    if (win != null) {
                        var b = win.attributes.screenBrightness
                        if (b < 0) b = 0.5f
                        result.success(b.toDouble())
                    } else result.success(0.5)
                }
                "setBrightness" -> {
                    val v = call.argument<Number>("value")?.toFloat() ?: 0.5f
                    val win = activity?.window
                    if (win != null) {
                        val attrs = win.attributes
                        attrs.screenBrightness = v.coerceIn(0f, 1f)
                        win.attributes = attrs
                    }
                    result.success(null)
                }
                "getVolume" -> {
                    val am = getSystemService(AUDIO_SERVICE) as AudioManager
                    val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    result.success(mapOf("cur" to cur, "max" to max))
                }
                "setVolume" -> {
                    val v = call.argument<Number>("value")?.toInt() ?: 0
                    val am = getSystemService(AUDIO_SERVICE) as AudioManager
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, v, 0)
                    result.success(null)
                }
                "videoThumb" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        Thread {
                            var retriever: android.media.MediaMetadataRetriever? = null
                            try {
                                retriever = android.media.MediaMetadataRetriever()
                                if (path.startsWith("content://")) {
                                    retriever.setDataSource(applicationContext, android.net.Uri.parse(path))
                                } else retriever.setDataSource(path)
                                val bmp = retriever.getFrameAtTime(1000000, android.media.MediaMetadataRetriever.OPTION_CLOSEST)
                                if (bmp != null) {
                                    val stream = java.io.ByteArrayOutputStream()
                                    val w = bmp.width; val h = bmp.height
                                    val scale = 320f / w; val nh = (h * scale).toInt()
                                    val scaled = android.graphics.Bitmap.createScaledBitmap(bmp, 320, nh, true)
                                    scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 75, stream)
                                    val bytes = stream.toByteArray()
                                    runOnUiThread { result.success(bytes) }
                                    scaled.recycle(); bmp.recycle()
                                } else runOnUiThread { result.success(null) }
                            } catch (e: Exception) { runOnUiThread { result.success(null) } }
                            finally { try { retriever?.release() } catch (_: Exception) {} }
                        }.start()
                    } else result.success(null)
                }

                // ── Уведомление / фон (только музыка) ──────────────────
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "AURA Player"
                    val artist = call.argument<String>("artist") ?: ""
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: true
                    val pos = (call.argument<Number>("pos")?.toLong() ?: 0L)
                    val dur = (call.argument<Number>("dur")?.toLong() ?: 0L)
                    lastTitle = title; lastArtist = artist; lastIsPlaying = isPlaying; lastPos = pos; lastDur = dur
                    startAudioService(title, artist, isPlaying, pos, dur)
                    result.success(true)
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: lastTitle
                    val artist = call.argument<String>("artist") ?: lastArtist
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: lastIsPlaying
                    val pos = (call.argument<Number>("pos")?.toLong() ?: lastPos)
                    val dur = (call.argument<Number>("dur")?.toLong() ?: lastDur)
                    lastTitle = title; lastArtist = artist; lastIsPlaying = isPlaying; lastPos = pos; lastDur = dur
                    // обновляем живой сервис без пересоздания
                    updateAudioService(title, artist, isPlaying, pos, dur)
                    result.success(true)
                }
                "hideNotification" -> {
                    hideAudioService()
                    result.success(true)
                }
                "requestNotifPermission" -> {
                    // На Android 13+ нужно запросить POST_NOTIFICATIONS — делаем через activity
                    if (Build.VERSION.SDK_INT >= 33) {
                        try { requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 9001) } catch (_: Throwable) {}
                    }
                    result.success(true)
                }

                // ── PiP ────────────────────────────────────────────────
                "enterPip" -> {
                    val w = call.argument<Number>("width")?.toInt() ?: 16
                    val h = call.argument<Number>("height")?.toInt() ?: 9
                    val ok = enterPipMode(w, h)
                    result.success(ok)
                }
                "isPipSupported" -> {
                    val ok = Build.VERSION.SDK_INT >= 26 && packageManager.hasSystemFeature("android.software.picture_in_picture")
                    result.success(ok)
                }
                "setPipAuto" -> { result.success(true) } // заглушка, логика в Dart

                // ── Визуализатор ───────────────────────────────────────
                "initVisualizer" -> {
                    val sid = call.argument<Number>("sessionId")?.toInt() ?: 0
                    val ok = VisualizerHelper.setSessionId(sid)
                    result.success(ok)
                }
                "setVisualizerEnabled" -> {
                    val en = call.argument<Boolean>("enabled") ?: true
                    VisualizerHelper.setEnabled(en)
                    result.success(true)
                }
                "hasVisualizer" -> {
                    result.success(true)
                }

                // Flutter спрашивает pending media action
                "consumeMediaAction" -> {
                    val a = pendingAction
                    pendingAction = null
                    result.success(a)
                }
                "consumeInitialOpen" -> {
                    val p = pendingOpenPath
                    pendingOpenPath = null
                    result.success(p)
                }
                "getInitialOpen" -> {
                    result.success(pendingOpenPath)
                }

                // ── VK: реальная идентификация устройства (A.b.y в LKMP) ──
                // android_id из Settings.Secure + Build.* — чтобы device_id и UA
                // выглядели как у настоящего устройства, а не как у подставного
                // Nexus 5X (главная причина антифрод-капчи при авторизации).
                "deviceIdentity" -> {
                    val map = HashMap<String, String>()
                    try {
                        map["androidId"] = android.provider.Settings.Secure.getString(
                            contentResolver, android.provider.Settings.Secure.ANDROID_ID
                        ) ?: ""
                    } catch (_: Throwable) { map["androidId"] = "" }
                    map["model"] = Build.MODEL ?: ""
                    map["manufacturer"] = Build.MANUFACTURER ?: ""
                    map["brand"] = Build.BRAND ?: ""
                    map["buildId"] = Build.ID ?: ""
                    map["type"] = Build.TYPE ?: ""
                    map["abi"] = if (Build.SUPPORTED_ABIS.isNotEmpty()) Build.SUPPORTED_ABIS[0] else ""
                    map["osRelease"] = Build.VERSION.RELEASE ?: ""
                    map["sdkInt"] = Build.VERSION.SDK_INT.toString()
                    result.success(map)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startAudioService(title: String, artist: String, isPlaying: Boolean, pos: Long, dur: Long) {
        val i = Intent(this, AudioService::class.java).apply {
            putExtra("title", title); putExtra("artist", artist); putExtra("isPlaying", isPlaying); putExtra("pos", pos); putExtra("dur", dur)
        }
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                try { startForegroundService(i) } catch (_: Throwable) { startService(i) }
            } else startService(i)
        } catch (_: Throwable) {
            // на некоторых прошивках без POST_NOTIFICATIONS может кинуть — игнор
        }
    }

    private fun updateAudioService(title: String, artist: String, isPlaying: Boolean, pos: Long, dur: Long) {
        // Если сервис уже бежит — просто шлём intent с новыми данными (service перезапустится)
        if (AudioService.isRunning) {
            startAudioService(title, artist, isPlaying, pos, dur)
        } else if (isPlaying) {
            // показываем только если играет — требование "плеер в строке уведомлений" при музыке
            startAudioService(title, artist, isPlaying, pos, dur)
        } else {
            // на паузе тоже показываем? да, чтобы было управление
            startAudioService(title, artist, isPlaying, pos, dur)
        }
    }

    private fun hideAudioService() {
        // если сервис не бежит — не трогаем систему, просто обновим виджет
        if (!AudioService.isRunning) {
            try { AuraWidgetProvider.pushUpdate(this, "AURA Player", "Остановлено", false, 0, 0) } catch (_: Throwable) {}
            return
        }
        try {
            val i = Intent(this, AudioService::class.java).apply { action = AudioService.ACTION_STOP }
            // на 14+ startForegroundService из фона может кинуть FGSNotAllowed — пробуем обычный
            try {
                if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
            } catch (_: Throwable) { try { startService(i) } catch (_: Throwable) {} }
        } catch (_: Throwable) {}
        try { AuraWidgetProvider.pushUpdate(this, "AURA Player", "Остановлено", false, 0, 0) } catch (_: Throwable) {}
    }

    private fun enterPipMode(w: Int, h: Int): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        if (!packageManager.hasSystemFeature("android.software.picture_in_picture")) return false
        return try {
            val rat = Rational(w.coerceIn(1, 1920), h.coerceIn(1, 1920))
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(rat)
                .build()
            enterPictureInPictureMode(params)
        } catch (_: Throwable) { false }
    }

    // Обработка intents от уведомления/виджета + VIEW (Открыть с помощью)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntentAction(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntentAction(intent)
    }

    private fun handleIntentAction(intent: Intent?) {
        if (intent == null) return
        val a = intent.action ?: return
        if (a.startsWith("AURA_")) {
            handleMediaAction(a)
            return
        }
        if (a == Intent.ACTION_VIEW || a == Intent.ACTION_SEND) {
            handleViewIntent(intent)
            return
        }
        // также проверяем наличие data даже без известного action (некоторые файловые менеджеры)
        if (intent.data != null && intent.type != null) {
            val t = intent.type ?: ""
            if (t.startsWith("video/") || t.startsWith("audio/")) {
                handleViewIntent(intent)
            }
        }
    }

    private fun handleViewIntent(intent: Intent) {
        // ACTION_SEND (share) тоже поддержим
        var uri = intent.data
        if (intent.action == Intent.ACTION_SEND) {
            uri = intent.getParcelableExtra(Intent.EXTRA_STREAM) as? android.net.Uri
                ?: intent.getStringExtra(Intent.EXTRA_TEXT)?.let { android.net.Uri.parse(it) }
        }
        if (uri == null) {
            // иногда data в виде clipData
            val clip = intent.clipData
            if (clip != null && clip.itemCount > 0) uri = clip.getItemAt(0).uri
        }
        if (uri == null) return
        val path = uri.toString()
        if (path.isBlank()) return
        // сохраняем для холодного старта
        pendingOpenPath = path
        // даём persist read permission для content://
        try {
            if (path.startsWith("content://")) {
                val flags = intent.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                if (flags != 0) contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        } catch (_: Throwable) {
            // на некоторых URI persist не поддерживается — игнор, флаг всё равно даст разовый доступ
        }
        // пробрасываем во Flutter
        try { channel?.invokeMethod("openFile", mapOf("path" to path)) } catch (_: Throwable) {}
    }

    private fun handleMediaAction(action: String) {
        pendingAction = action
        // пробрасываем во Flutter если уже подключён
        try { channel?.invokeMethod("mediaAction", mapOf("action" to action)) } catch (_: Throwable) {}
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Авто-PiP для видео — сигнал во Flutter, он сам решит
        try { channel?.invokeMethod("onUserLeaveHint", null) } catch (_: Throwable) {}
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        try { channel?.invokeMethod("pipChanged", mapOf("inPip" to isInPictureInPictureMode)) } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        try { unregisterReceiver(mediaActionReceiver) } catch (_: Throwable) {}
        super.onDestroy()
    }
}
