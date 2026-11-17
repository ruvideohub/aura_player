package com.example.aura_player

import android.media.AudioManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// AURA Player — точка входа Android.
/// Регистрирует Platform Channel «aura.player/native», через который
/// Dart-слой обращается к Kotlin: скан MediaStore, обложки,
/// системный эквалайзер и бас-буст.
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "aura.player/native"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanMedia" -> MediaStoreScanner.scan(applicationContext, result)
                "albumArt" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaStoreScanner.albumArt(applicationContext, path, result)
                    } else {
                        result.success(null)
                    }
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
                // Жесты: яркость и громкость — как в твоём Compose (без белого оверлея)
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
                else -> result.notImplemented()
            }
        }
    }
}
