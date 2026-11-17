package com.example.aura_player

import android.content.Context
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.ResolvingDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter
import io.flutter.view.TextureRegistry
import java.io.File
import okhttp3.OkHttpClient

/**
 * Минимальный порт твоего ExoPlayerHandler для AURA.
 * Даёт тот же буст: кэш 500МБ + OkHttp + HLS/DASH + reuse + LoadControl.
 * Подключается через MethodChannel "aura_fast_player" -> Texture id на Flutter.
 */
object FastExoPlayerHolder {
    private var cache: SimpleCache? = null
    private var player: ExoPlayer? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null

    fun initCache(context: Context, maxBytes: Long = 500L*1024*1024) {
        if (cache != null) return
        val dir = File(context.cacheDir, "aura_exo_cache").apply { mkdirs() }
        cache = SimpleCache(dir, LeastRecentlyUsedCacheEvictor(maxBytes), StandaloneDatabaseProvider(context))
    }

    fun getOrCreate(context: Context, textures: TextureRegistry, isLive: Boolean): Pair<ExoPlayer, Long> {
        player?.let { return it to (textureEntry?.id() ?: -1L) }
        initCache(context)

        val okHttp = OkHttpClient.Builder().build()
        val httpFactory = OkHttpDataSource.Factory(okHttp)
            .setUserAgent("AURA-Player/2.0 (Android; ExoPlayer)")
            .setDefaultRequestProperties(mapOf("Accept" to "*/*"))

        val upstream: DataSource.Factory = DefaultDataSource.Factory(context, httpFactory)
        val cacheDs = cache?.let {
            CacheDataSource.Factory()
                .setCache(it)
                .setUpstreamDataSourceFactory(upstream)
                .setCacheWriteDataSinkFactory(null) // не пишем live
        } ?: upstream

        // ResolvingDataSource — заголовки на каждый чанк, как в твоём примере
        val ds: DataSource.Factory = ResolvingDataSource.Factory(cacheDs) { spec ->
            // сюда прокинуть HeaderResolver.headersFor(spec.uri.toString(), source)
            // пока отдаём без доп. заголовков — добавь свои
            spec
        }

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                if (isLive) 15_000 else 30_000, // min
                if (isLive) 30_000 else 60_000, // max
                if (isLive) 500 else 2000,      // playback
                if (isLive) 500 else 2000       // rebuffer
            ).build()

        val trackSelector = DefaultTrackSelector(context).apply {
            parameters = buildUponParameters()
                .setPreferredAudioMimeTypes(MimeTypes.AUDIO_AAC, MimeTypes.AUDIO_OPUS)
                .setAllowMultipleAdaptiveSelections(false)
                .build()
        }

        val bwMeter = DefaultBandwidthMeter.Builder(context).setInitialBitrateEstimate(1_000_000).build()

        val msFactory = DefaultMediaSourceFactory(context).setDataSourceFactory(ds)

        val exo = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setTrackSelector(trackSelector)
            .setBandwidthMeter(bwMeter)
            .setMediaSourceFactory(object: androidx.media3.exoplayer.source.MediaSource.Factory by msFactory {
                override fun createMediaSource(item: MediaItem): androidx.media3.exoplayer.source.MediaSource {
                    val uri = item.localConfiguration?.uri.toString()
                    val mime = item.localConfiguration?.mimeType
                    val isHls = mime == MimeTypes.APPLICATION_M3U8 || uri.contains(".m3u8")
                    val isDash = mime == MimeTypes.APPLICATION_MPD || uri.contains(".mpd")
                    return when {
                        isHls -> HlsMediaSource.Factory(ds).setAllowChunklessPreparation(!isLive).createMediaSource(item)
                        isDash -> DashMediaSource.Factory(ds).createMediaSource(item)
                        else -> msFactory.createMediaSource(item)
                    }
                }
            })
            .build()

        val entry = textures.createSurfaceTexture()
        exo.setVideoSurfaceTexture(entry.surfaceTexture())
        textureEntry = entry
        player = exo
        return exo to entry.id()
    }

    fun release() {
        try { player?.stop(); player?.release() } catch (_:Exception) {}
        player = null
        try { textureEntry?.release() } catch (_:Exception) {}
        textureEntry = null
    }
}
