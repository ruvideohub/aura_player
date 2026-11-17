package com.example.aura_player

import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/// Скан музыки и видео на устройстве через MediaStore + извлечение обложек.
/// Запросы выполняются в фоновом потоке, результат доставляется в main-поток.
object MediaStoreScanner {

    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun scan(context: Context, result: MethodChannel.Result) {
        executor.execute {
            val items = ArrayList<Map<String, Any?>>()
            try {
                items += queryAudio(context)
                items += queryVideo(context)
                main.post { result.success(items) }
            } catch (t: Throwable) {
                main.post { result.error("SCAN_ERROR", t.message, null) }
            }
        }
    }

    fun albumArt(context: Context, path: String, result: MethodChannel.Result) {
        executor.execute {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(path)
                val bytes = retriever.embeddedPicture
                main.post { result.success(bytes) }
            } catch (t: Throwable) {
                main.post { result.success(null) }
            } finally {
                try {
                    retriever.release()
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun queryAudio(context: Context): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val collection =
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_ADDED,
        )
        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC",
        )?.use { c ->
            while (c.moveToNext()) {
                val path = c.getStringOrNull(3) ?: continue
                out.add(
                    mapOf(
                        "path" to path,
                        "title" to (c.getStringOrNull(0) ?: ""),
                        "artist" to (c.getStringOrNull(1) ?: ""),
                        "album" to (c.getStringOrNull(2) ?: ""),
                        "durationMs" to (c.getLongOrNull(4) ?: 0L),
                        "sizeBytes" to (c.getLongOrNull(5) ?: 0L),
                        "addedAt" to ((c.getLongOrNull(6) ?: 0L) * 1000L),
                        "isVideo" to false,
                    )
                )
            }
        }
        return out
    }

    private fun queryVideo(context: Context): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val collection =
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_ADDED,
        )
        context.contentResolver.query(
            collection,
            projection,
            null,
            null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC",
        )?.use { c ->
            while (c.moveToNext()) {
                val path = c.getStringOrNull(1) ?: continue
                out.add(
                    mapOf(
                        "path" to path,
                        "title" to (c.getStringOrNull(0) ?: ""),
                        "artist" to "",
                        "album" to "",
                        "durationMs" to (c.getLongOrNull(2) ?: 0L),
                        "sizeBytes" to (c.getLongOrNull(3) ?: 0L),
                        "addedAt" to ((c.getLongOrNull(4) ?: 0L) * 1000L),
                        "isVideo" to true,
                    )
                )
            }
        }
        return out
    }

    private fun android.database.Cursor.getStringOrNull(index: Int): String? {
        return if (isNull(index)) null else getString(index)
    }

    private fun android.database.Cursor.getLongOrNull(index: Int): Long? {
        return if (isNull(index)) null else getLong(index)
    }
}
