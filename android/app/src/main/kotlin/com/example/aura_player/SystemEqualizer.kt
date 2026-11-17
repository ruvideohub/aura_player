package com.example.aura_player

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import io.flutter.plugin.common.MethodChannel

/// Системный эквалайзер Android (audiofx), подключается к глобальному
/// выходному миксу. Уровни задаются в миллибеллах (дБ * 100).
/// Эквалайзер-фильтр mpv на Windows заменяет этот слой.
object SystemEqualizer {

    private var eq: Equalizer? = null
    private var bass: BassBoost? = null

    private fun ensure(): Equalizer? = try {
        eq ?: Equalizer(0, 0).also { eq = it }
    } catch (_: Throwable) {
        null
    }

    fun setEnabled(on: Boolean, result: MethodChannel.Result) {
        val e = ensure()
        if (e == null) {
            result.success(false)
            return
        }
        try {
            e.setEnabled(on)
            bass?.setEnabled(on)
            result.success(true)
        } catch (t: Throwable) {
            result.error("EQ_ERROR", t.message, null)
        }
    }

    fun setGains(gains: List<Double>, result: MethodChannel.Result) {
        val e = ensure()
        if (e == null) {
            result.success(false)
            return
        }
        try {
            val range = e.bandLevelRange
            val bands = e.numberOfBands.toInt()
            val n = minOf(bands, gains.size)
            for (i in 0 until n) {
                val mb = (gains[i] * 100).toInt()
                    .coerceIn(range[0].toInt(), range[1].toInt())
                e.setBandLevel(i.toShort(), mb.toShort())
            }
            result.success(true)
        } catch (t: Throwable) {
            result.error("EQ_ERROR", t.message, null)
        }
    }

    fun setBassBoost(strength: Int, result: MethodChannel.Result) {
        try {
            val b = bass ?: BassBoost(0, 0).also { bass = it }
            b.setEnabled(strength > 0)
            b.setStrength(strength.coerceIn(0, 1000).toShort())
            result.success(true)
        } catch (t: Throwable) {
            result.error("EQ_ERROR", t.message, null)
        }
    }
}
