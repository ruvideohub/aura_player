package com.example.aura_player

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
                else -> result.notImplemented()
            }
        }
    }
}
