import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'media_store_service.dart';

import '../core/track.dart';
import '../core/constants.dart';

/// Dual-mode library indexer — Namida architecture:
///   Mode A: MediaStore  — fast, covers all indexed audio
///   Mode B: Direct FS walk — covers sideloaded/non-indexed files
///
/// Both modes run, results are merged and deduplicated by file path.
class IndexerService {
  static final IndexerService inst = IndexerService._();
  IndexerService._();

  // Progress stream for UI
  final _progressController = StreamController<IndexProgress>.broadcast();
  Stream<IndexProgress> get progress => _progressController.stream;

  /// Request storage permission (Android 13+ = READ_MEDIA_AUDIO).
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();
      if (status.isGranted) return true;
      // Fallback for Android < 13
      final legacy = await Permission.storage.request();
      return legacy.isGranted;
    }
    return true;
  }

  /// Full scan: MediaStore + direct FS walk on checked folders.
  /// Returns merged, deduplicated track list.
  Future<List<Track>> scanAll({
    List<String> checkedFolders = const [],
    List<String> excludedFolders = const [],
  }) async {
    _emit(IndexProgress(phase: 'Requesting permission…', done: 0, total: 0));

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      _emit(IndexProgress(phase: 'Permission denied', done: 0, total: 0, error: true));
      return [];
    }

    // Run both modes concurrently
    _emit(IndexProgress(phase: 'Scanning device…', done: 0, total: 0));

    final results = await Future.wait([
      _scanMediaStore(checkedFolders: checkedFolders, excludedFolders: excludedFolders),
      _scanFilesystem(checkedFolders: checkedFolders, excludedFolders: excludedFolders),
    ]);

    final fromStore = results[0];
    final fromFs    = results[1];

    // Merge: MediaStore is authoritative, FS fills gaps.
    // Deduplicate by PHYSICAL file path — MediaStore uses content:// URIs
    // so t.path never matches FS paths; use filePath (or path for FS tracks).
    final seen = <String>{};
    final merged = <Track>[];

    String _key(Track t) => t.filePath.isNotEmpty ? t.filePath : t.path;

    for (final t in fromStore) {
      if (seen.add(_key(t))) merged.add(t);
    }
    for (final t in fromFs) {
      if (seen.add(_key(t))) merged.add(t);
    }

    // Sort by title
    merged.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    _emit(IndexProgress(phase: 'Done', done: merged.length, total: merged.length));
    return merged;
  }

  // ── Mode A: MediaStore (via embedded Kotlin plugin, Namida pattern) ─

  Future<List<Track>> _scanMediaStore({
    List<String> checkedFolders = const [],
    List<String> excludedFolders = const [],
  }) async {
    try {
      _emit(IndexProgress(phase: 'MediaStore scan…', done: 0, total: 0));
      final tracks = await MediaStoreService.inst.scanTracks(
        folders: checkedFolders.isNotEmpty ? checkedFolders : null,
      );
      return tracks
          .where((t) => !_isExcluded(t.path, excludedFolders))
          .where((t) => !_hasNomedia(t.path))
          .toList();
    } catch (e) {
      debugPrint('MediaStore scan failed: $e');
      return [];
    }
  }

  // ── Mode B: Direct filesystem walk (Namida DirsFileFilter) ─────

  Future<List<Track>> _scanFilesystem({
    List<String> checkedFolders = const [],
    List<String> excludedFolders = const [],
  }) async {
    // Determine root dirs to walk
    final roots = checkedFolders.isNotEmpty
        ? checkedFolders.map((p) => Directory(p)).toList()
        : await _defaultMusicDirs();

    final audioFiles = <String>[];
    for (final dir in roots) {
      if (!await dir.exists()) continue;
      await _walkDir(dir, audioFiles, excludedFolders);
    }

    if (audioFiles.isEmpty) return [];

    _emit(IndexProgress(phase: 'Extracting metadata…', done: 0, total: audioFiles.length));

    // Parallel extraction — Namida splits across CPU cores
    final cpuCount = Platform.numberOfProcessors;
    final chunkSize = (audioFiles.length / (cpuCount * 0.5).ceil()).ceil().clamp(1, 200);
    final chunks = <List<String>>[];
    for (int i = 0; i < audioFiles.length; i += chunkSize) {
      chunks.add(audioFiles.sublist(i, (i + chunkSize).clamp(0, audioFiles.length)));
    }

    int done = 0;
    final allTracks = <Track>[];
    final completer = Completer<void>();

    for (final chunk in chunks) {
      compute(_extractChunk, chunk).then((tracks) {
        allTracks.addAll(tracks);
        done += chunk.length;
        _emit(IndexProgress(phase: 'Extracting metadata…', done: done, total: audioFiles.length));
        if (done >= audioFiles.length) completer.complete();
      });
    }

    await completer.future.timeout(const Duration(minutes: 10), onTimeout: () {});
    return allTracks;
  }

  Future<void> _walkDir(Directory dir, List<String> out, List<String> excluded) async {
    if (_isExcluded(dir.path, excluded)) return;
    // Respect .nomedia
    if (await File('${dir.path}/.nomedia').exists()) return;

    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is Directory) {
          await _walkDir(entity, out, excluded);
        } else if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (kAudioExtensions.contains(ext)) {
            out.add(entity.path);
          }
        }
      }
    } catch (_) {}
  }

  Future<List<Directory>> _defaultMusicDirs() async {
    final dirs = <Directory>[];
    // Standard Android paths
    for (final base in ['/storage/emulated/0']) {
      for (final sub in ['Music', 'Download', 'DCIM']) {
        final d = Directory('$base/$sub');
        if (await d.exists()) dirs.add(d);
      }
    }
    return dirs;
  }

  // ── Helpers ────────────────────────────────────────────────────

  bool _hasNomedia(String path) {
    return File('${_folderOf(path)}/.nomedia').existsSync();
  }

  bool _isExcluded(String path, List<String> excluded) {
    return excluded.any((e) => path.startsWith(e));
  }

  String _folderOf(String path) {
    final i = path.lastIndexOf('/');
    return i >= 0 ? path.substring(0, i) : '/';
  }

  String _titleFromPath(String path) {
    final name = path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
    final parts = name.split(' - ');
    return parts.length >= 2 ? parts.skip(1).join(' - ').trim() : name;
  }

  String _sanitizeArtist(String? s) {
    if (s == null || s.isEmpty || s == '<unknown>') return 'Unknown Artist';
    return s;
  }

  String _codecFromPath(String path) {
    final ext = path.split('.').last.toUpperCase();
    const known = {'MP3','FLAC','M4A','AAC','OGG','OPUS','WAV','WMA','APE','ALAC','MKA','M4B'};
    return known.contains(ext) ? ext : 'MP3';
  }

  bool _isLossless(String path) {
    final ext = path.split('.').last.toLowerCase();
    return const {'flac', 'alac', 'wav', 'ape', 'aiff'}.contains(ext);
  }

  void _emit(IndexProgress p) {
    if (!_progressController.isClosed) _progressController.add(p);
  }
}

// ── Isolate worker — filename-based extraction (runs off main thread) ─
// MediaStore provides full metadata for indexed files.
// For sideloaded files not in MediaStore, we parse "Artist - Title.ext" filenames.

Future<List<Track>> _extractChunk(List<String> paths) async {
  final tracks = <Track>[];
  for (final path in paths) {
    try {
      final stat  = await File(path).stat();
      final name  = path.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final parts = name.split(' - ');
      final title  = parts.length >= 2 ? parts.skip(1).join(' - ').trim() : name;
      final rawArtist = parts.length >= 2 ? parts.first.trim() : '';
      // Reject track-number prefixes like "01", "01.", "Track 01"
      final artist = (rawArtist.isNotEmpty &&
              !RegExp(r'^(track\s*)?\d{1,3}\.?$', caseSensitive: false).hasMatch(rawArtist))
          ? rawArtist
          : 'Unknown Artist';
      final ext    = path.split('.').last.toUpperCase();

      const lossless = {'FLAC', 'ALAC', 'WAV', 'APE', 'AIFF'};
      const known    = {'MP3','FLAC','M4A','AAC','OGG','OPUS','WAV','WMA','APE','ALAC','MKA','M4B'};

      tracks.add(Track(
        path: path, title: title, artist: artist,
        album: 'Unknown Album',
        durationMs: 0,
        fileSize: stat.size,
        codec: known.contains(ext) ? ext : 'MP3',
        isLossless: lossless.contains(ext),
      ));
    } catch (_) {}
  }
  return tracks;
}

class IndexProgress {
  final String phase;
  final int done;
  final int total;
  final bool error;
  IndexProgress({required this.phase, required this.done, required this.total, this.error = false});
  double get fraction => total > 0 ? done / total : 0;
}
