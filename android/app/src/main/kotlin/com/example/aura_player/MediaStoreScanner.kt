package com.example.aura_player

import android.content.ContentUris
import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/// Скан музыки и видео на устройстве через MediaStore + извлечение обложек.
/// Исправлено для Android 10+ (scoped storage): используем content:// URIs
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
                // Поддержка как file:// так и content://
                if (path.startsWith("content://")) {
                    val uri = android.net.Uri.parse(path)
                    retriever.setDataSource(context, uri)
                } else {
                    retriever.setDataSource(path)
                }
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
            MediaStore.Audio.Media._ID,
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
            val idIndex = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val dataIndex = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            while (c.moveToNext()) {
                val id = c.getLong(idIndex)
                // Приоритет: content:// URI (работает на Android 10+), fallback на DATA
                val filePath = c.getStringOrNull(dataIndex)
                val contentUri = ContentUris.withAppendedId(collection, id).toString()
                // Используем filePath если он есть и файл существует, иначе contentUri
                val path = if (!filePath.isNullOrEmpty() && java.io.File(filePath).exists()) filePath else contentUri
                
                out.add(
                    mapOf(
                        "path" to path,
                        "title" to (c.getStringOrNull(c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)) ?: ""),
                        "artist" to (c.getStringOrNull(c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)) ?: ""),
                        "album" to (c.getStringOrNull(c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)) ?: ""),
                        "durationMs" to (c.getLongOrNull(c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)) ?: 0L),
                        "sizeBytes" to (c.getLongOrNull(c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)) ?: 0L),
                        "addedAt" to ((c.getLongOrNull(c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)) ?: 0L) * 1000L),
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
            MediaStore.Video.Media._ID,
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
            val idIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val dataIndex = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
            while (c.moveToNext()) {
                val id = c.getLong(idIndex)
                val filePath = c.getStringOrNull(dataIndex)
                val contentUri = ContentUris.withAppendedId(collection, id).toString()
                val path = if (!filePath.isNullOrEmpty() && java.io.File(filePath).exists()) filePath else contentUri
                
                out.add(
                    mapOf(
                        "path" to path,
                        "title" to (c.getStringOrNull(c.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)) ?: ""),
                        "artist" to "",
                        "album" to "",
                        "durationMs" to (c.getLongOrNull(c.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)) ?: 0L),
                        "sizeBytes" to (c.getLongOrNull(c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)) ?: 0L),
                        "addedAt" to ((c.getLongOrNull(c.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)) ?: 0L) * 1000L),
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
