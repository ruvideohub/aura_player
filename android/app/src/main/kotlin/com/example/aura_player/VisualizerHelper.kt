package com.example.aura_player

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Реальный аудио-визуализатор на Android Visualizer API.
 * Берёт данные прямо из аудио-потока, а не фейк-синус.
 * Поддерживает 3 режима отрисовки на Dart, но данные — реальные FFT/waveform.
 *
 * Работает в двух режимах:
 *  session 0 — output mix (требует RECORD_AUDIO, на некоторых прошивках может не дать)
 *  конкретный sessionId — если Dart передаст audioSessionId от ExoPlayer (идеально)
 */
object VisualizerHelper : EventChannel.StreamHandler {

    private var visualizer: Visualizer? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private var captureRate = 20000 // 20 Гц ~ 50мс
    private var lastFft: ByteArray? = null
    private var lastWave: ByteArray? = null
    private var pendingEnable = false

    fun isAvailable(): Boolean = true

    private fun create(sessionId: Int): Boolean {
        release()
        return try {
            val v = Visualizer(sessionId)
            // captureSize должен быть степень двойки в [128..1024]
            v.captureSize = Visualizer.getCaptureSizeRange()[1].coerceAtMost(512)
            // слушаем оба типа данных
            v.setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                override fun onWaveFormDataCapture(vis: Visualizer?, waveform: ByteArray?, rate: Int) {
                    if (waveform != null) {
                        lastWave = waveform
                        maybeEmit()
                    }
                }
                override fun onFftDataCapture(vis: Visualizer?, fft: ByteArray?, rate: Int) {
                    if (fft != null) {
                        lastFft = fft
                        maybeEmit()
                    }
                }
            }, captureRate, true, true)
            // если есть sink — включаем
            visualizer = v
            if (sink != null && (pendingEnable || true)) {
                v.enabled = true
            }
            true
        } catch (t: Throwable) {
            // Visualizer не поддерживается или нет разрешения
            visualizer = null
            false
        }
    }

    private fun maybeEmit() {
        val s = sink ?: return
        val fft = lastFft ?: return
        val wave = lastWave ?: return
        // отправляем на main thread
        main.post {
            try {
                // Формат: Map с двумя массивами int (0..255 unsigned)
                // Dart получит их как List<int> — конвертим в unsigned
                val fftU = ArrayList<Int>(fft.size)
                for (b in fft) fftU.add(b.toInt() and 0xFF)
                val waveU = ArrayList<Int>(wave.size)
                for (b in wave) waveU.add(b.toInt() and 0xFF)
                s.success(mapOf("fft" to fftU, "waveform" to waveU))
            } catch (_: Throwable) {}
        }
    }

    fun setEnabled(enabled: Boolean) {
        pendingEnable = enabled
        try { visualizer?.enabled = enabled } catch (_: Throwable) {}
    }

    fun setSessionId(sessionId: Int): Boolean {
        // пересоздаём с новым session
        return create(sessionId)
    }

    fun release() {
        try { visualizer?.enabled = false } catch (_: Throwable) {}
        try { visualizer?.release() } catch (_: Throwable) {}
        visualizer = null
        lastFft = null
        lastWave = null
    }

    // EventChannel.StreamHandler
    override fun onListen(args: Any?, events: EventChannel.EventSink?) {
        sink = events
        // args может содержать {"sessionId": 0, "rate": 20000}
        var sid = 0
        if (args is Map<*, *>) {
            sid = (args["sessionId"] as? Number)?.toInt() ?: 0
            captureRate = (args["rate"] as? Number)?.toInt() ?: 20000
        }
        val ok = create(sid)
        if (!ok) {
            // сообщим ошибку — Dart перейдёт на фейк
            try { events?.error("VISUALIZER_UNAVAILABLE", "Visualizer not supported or permission denied (RECORD_AUDIO)", null) } catch (_: Throwable) {}
            // всё равно не закрываем sink — пусть Dart знает
            return
        }
        pendingEnable = true
        try { visualizer?.enabled = true } catch (_: Throwable) {}
    }

    override fun onCancel(args: Any?) {
        sink = null
        pendingEnable = false
        release()
    }
}
