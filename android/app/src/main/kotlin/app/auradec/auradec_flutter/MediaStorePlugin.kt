package app.auradec.auradec_flutter

import android.Manifest
import android.content.ContentUris
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MediaStorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        binding = b
        channel = MethodChannel(b.binaryMessenger, "app.auradec/media_store")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "scanTracks"    -> scanTracks(call.argument("folders"), result)
            "getFolders"    -> getFolders(result)
            "getArtwork"    -> getArtwork(call.argument("uri") ?: "", call.argument("filePath") ?: "", result)
            else            -> result.notImplemented()
        }
    }

    // ── Artwork ────────────────────────────────────────────────────────────────

    private fun getArtwork(uri: String, filePath: String, result: MethodChannel.Result) {
        // 1. Try the content:// albumart URI first (fastest)
        if (uri.isNotEmpty()) {
            try {
                val stream = binding.applicationContext.contentResolver
                    .openInputStream(Uri.parse(uri))
                if (stream != null) {
                    val bytes = stream.readBytes(); stream.close()
                    if (bytes.isNotEmpty()) { result.success(bytes); return }
                }
            } catch (_: Exception) {}
        }
        // 2. Fall back to embedded art via MediaMetadataRetriever
        if (filePath.isNotEmpty() && File(filePath).exists()) {
            try {
                val mmr = MediaMetadataRetriever()
                mmr.setDataSource(filePath)
                val bytes = mmr.embeddedPicture
                mmr.release()
                if (bytes != null && bytes.isNotEmpty()) { result.success(bytes); return }
            } catch (_: Exception) {}
        }
        result.success(null)
    }

    // ── Scan ──────────────────────────────────────────────────────────────────

    private fun scanTracks(allowedFolders: List<String>?, result: MethodChannel.Result) {
        val ctx        = binding.applicationContext
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val artBase    = "content://media/external/audio/albumart"

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ARTIST,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.BITRATE,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.DISC_NUMBER,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DATA,
        )

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} > 10000"
        val tracks    = mutableListOf<Map<String, Any>>()

        try {
            val cursor = ctx.contentResolver.query(
                collection, projection, selection, null,
                "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
            )
            cursor?.use { c ->
                val idxId         = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val idxTitle      = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val idxArtist     = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val idxAlbum      = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val idxAlbumArt   = c.getColumnIndex(MediaStore.Audio.Media.ALBUM_ARTIST)
                val idxDur        = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val idxBitrate    = c.getColumnIndex(MediaStore.Audio.Media.BITRATE)
                val idxMime       = c.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
                val idxSize       = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val idxYear       = c.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
                val idxTrack      = c.getColumnIndex(MediaStore.Audio.Media.TRACK)
                val idxDisc       = c.getColumnIndex(MediaStore.Audio.Media.DISC_NUMBER)
                val idxAlbumId    = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val idxData       = c.getColumnIndex(MediaStore.Audio.Media.DATA)

                while (c.moveToNext()) {
                    val filePath = if (idxData >= 0) c.getString(idxData) ?: "" else ""
                    val folder   = if (filePath.contains("/")) filePath.substringBeforeLast("/") else "/"

                    if (!allowedFolders.isNullOrEmpty()) {
                        val match = allowedFolders.any { f -> folder == f || folder.startsWith("$f/") }
                        if (!match) continue
                    }

                    val mediaId = c.getLong(idxId)
                    val albumId = c.getLong(idxAlbumId)
                    val durMs   = c.getLong(idxDur)
                    val size    = c.getLong(idxSize)
                    val bitrate = if (idxBitrate >= 0) c.getInt(idxBitrate) else 0

                    // MediaStore metadata — may be "<unknown>" on some devices
                    var title      = sanitize(c.getString(idxTitle))
                    var artist     = sanitize(c.getString(idxArtist))
                    var album      = sanitize(c.getString(idxAlbum))
                    var albumArtist= if (idxAlbumArt >= 0) sanitize(c.getString(idxAlbumArt)) else null
                    var year       = c.getInt(idxYear)
                    var trackNo    = if (idxTrack >= 0) c.getInt(idxTrack) % 1000 else 0
                    var discNo     = if (idxDisc >= 0) c.getInt(idxDisc) else 1

                    // Enrich with MediaMetadataRetriever if MediaStore fields are empty
                    if ((title == null || artist == null || album == null) && filePath.isNotEmpty()) {
                        try {
                            val mmr = MediaMetadataRetriever()
                            mmr.setDataSource(filePath)
                            if (title   == null) title      = sanitize(mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE))
                            if (artist  == null) artist     = sanitize(mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST))
                            if (album   == null) album      = sanitize(mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM))
                            if (albumArtist == null) albumArtist = sanitize(mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST))
                            if (year    == 0) {
                                val y = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR)?.toIntOrNull()
                                if (y != null) year = y
                            }
                            if (trackNo == 0) {
                                val tn = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER)?.split("/")?.firstOrNull()?.toIntOrNull()
                                if (tn != null) trackNo = tn
                            }
                            mmr.release()
                        } catch (_: Exception) {}
                    }

                    val t = mutableMapOf<String, Any>()
                    t["id"]          = mediaId
                    t["path"]        = ContentUris.withAppendedId(collection, mediaId).toString()
                    t["filePath"]    = filePath
                    t["artUri"]      = ContentUris.withAppendedId(Uri.parse(artBase), albumId).toString()
                    t["title"]       = title  ?: titleFromPath(filePath)
                    t["artist"]      = artist ?: "Unknown Artist"
                    t["albumArtist"] = albumArtist ?: ""
                    t["album"]       = album  ?: "Unknown Album"
                    t["durationMs"]  = durMs
                    t["bitrate"]     = if (bitrate > 0) bitrate else if (durMs > 0) ((size * 8L) / (durMs / 1000L * 1000L)).toInt() else 0
                    t["sampleRate"]  = 44100
                    t["fileSize"]    = size
                    t["year"]        = year
                    t["trackNo"]     = trackNo
                    t["discNo"]      = discNo
                    t["codec"]       = mimeToCodec(c.getString(idxMime))
                    t["folder"]      = folder
                    tracks.add(t)
                }
            }
            result.success(tracks)
        } catch (e: Exception) {
            result.error("SCAN_FAILED", e.message, null)
        }
    }

    // ── Folders ────────────────────────────────────────────────────────────────

    private fun getFolders(result: MethodChannel.Result) {
        val ctx        = binding.applicationContext
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Audio.Media.DATA, MediaStore.Audio.Media.ALBUM_ID)
        val selection  = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} > 10000"
        val folderMap  = linkedMapOf<String, LongArray>()

        try {
            ctx.contentResolver.query(collection, projection, selection, null,
                "${MediaStore.Audio.Media.DATA} ASC")?.use { c ->
                val idxData    = c.getColumnIndex(MediaStore.Audio.Media.DATA)
                val idxAlbumId = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                while (c.moveToNext()) {
                    val data   = if (idxData >= 0) c.getString(idxData) ?: "" else ""
                    val folder = if (data.contains("/")) data.substringBeforeLast("/") else "/"
                    val entry  = folderMap.getOrPut(folder) { LongArray(2) }
                    entry[0]++
                    if (entry[1] == 0L) entry[1] = c.getLong(idxAlbumId)
                }
            }
            val artBase = "content://media/external/audio/albumart"
            result.success(folderMap.map { (path, v) ->
                mapOf("path" to path, "name" to path.substringAfterLast("/"),
                    "count" to v[0].toInt(),
                    "artUri" to ContentUris.withAppendedId(Uri.parse(artBase), v[1]).toString())
            })
        } catch (e: Exception) {
            result.error("FOLDERS_FAILED", e.message, null)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun sanitize(s: String?): String? {
        if (s == null) return null
        val t = s.trim()
        return if (t.isBlank() || t == "<unknown>" || t.equals("unknown", ignoreCase = true)) null else t
    }

    private fun titleFromPath(path: String): String {
        val name  = path.substringAfterLast("/").substringBeforeLast(".")
        val parts = name.split(" - ")
        return if (parts.size >= 2) parts.drop(1).joinToString(" - ").trim() else name
    }

    private fun mimeToCodec(mime: String?): String = when {
        mime == null             -> "MP3"
        "flac"  in mime          -> "FLAC"
        "ogg"   in mime          -> "OGG"
        "opus"  in mime          -> "OPUS"
        "mp4"   in mime || "m4a" in mime -> "M4A"
        "aac"   in mime          -> "AAC"
        "wav"   in mime          -> "WAV"
        "wma"   in mime          -> "WMA"
        else                     -> "MP3"
    }

    private fun hasPermission(): Boolean {
        val ctx = binding.applicationContext
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        else
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }
}
