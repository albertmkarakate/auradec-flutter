import 'package:flutter/services.dart';
import '../core/track.dart';

/// Dart bridge for the embedded MediaStorePlugin Kotlin channel.
/// Namida namida_storage_android pattern — no third-party package.
class MediaStoreService {
  static final MediaStoreService inst = MediaStoreService._();
  MediaStoreService._();

  static const _ch = MethodChannel('app.auradec/media_store');

  Future<bool> hasPermission() async {
    try { return await _ch.invokeMethod<bool>('hasPermission') ?? false; }
    catch (_) { return false; }
  }

  /// Scan all audio from MediaStore, optionally filtered to folder paths.
  Future<List<Track>> scanTracks({List<String>? folders}) async {
    final raw = await _ch.invokeMethod<List<dynamic>>(
      'scanTracks',
      {'folders': folders ?? <String>[]},
    );
    if (raw == null) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return Track(
        path:        m['path']        as String,
        title:       m['title']       as String,
        artist:      m['artist']      as String,
        albumArtist: m['albumArtist'] as String,
        album:       m['album']       as String,
        year:        m['year']        as int,
        trackNo:     m['trackNo']     as int,
        durationMs:  (m['durationMs'] as num).toInt(),
        bitrate:     m['bitrate']     as int,
        sampleRate:  m['sampleRate']  as int,
        fileSize:    (m['fileSize']   as num).toInt(),
        codec:       m['codec']       as String,
        isLossless:  (m['codec'] as String).toUpperCase() == 'FLAC' || (m['codec'] as String).toUpperCase() == 'WAV',
      )..artUri = m['artUri'] as String?;
    }).toList();
  }

  /// Get all folders containing audio (for Musicolet-style folder picker).
  Future<List<FolderInfo>> getFolders() async {
    final raw = await _ch.invokeMethod<List<dynamic>>('getFolders');
    if (raw == null) return [];
    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return FolderInfo(
        path:   m['path']   as String,
        name:   m['name']   as String,
        count:  m['count']  as int,
        artUri: m['artUri'] as String?,
      );
    }).toList();
  }
}

class FolderInfo {
  final String path;
  final String name;
  final int    count;
  final String? artUri;
  FolderInfo({required this.path, required this.name, required this.count, this.artUri});
}
