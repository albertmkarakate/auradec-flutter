import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/track.dart';
import '../core/constants.dart';
import '../services/indexer_service.dart';
import '../services/smart_playlist_engine.dart';
import '../services/tag_writer_service.dart';

// ignore_for_file: avoid_function_literals_in_foreach_calls

/// Library controller — Namida-style singleton.
/// Owns the canonical track list, derived maps, and persistence.
class LibraryController extends GetxController {
  static LibraryController get inst => Get.find();

  // ── State ─────────────────────────────────────────────────────────
  final tracks         = <Track>[].obs;
  final albums         = <String, List<Track>>{}.obs;
  final artists        = <String, List<Track>>{}.obs;
  final folders        = <String, List<Track>>{}.obs;
  final isScanning     = false.obs;
  final scanPhase      = ''.obs;
  final scanProgress   = 0.0.obs;
  final excludedPaths  = <String>{}.obs;
  final checkedFolders = <String>[].obs;  // empty = scan all

  // Ratings stored separately (Namida two-DB pattern)
  final ratings    = <String, int>{}.obs;
  final lovedPaths = <String>{}.obs;
  final playlists  = <Playlist>[].obs;

  // Followed artists
  final followedArtists = <String>{}.obs;

  // Artist separator config — persisted, used when building artist map
  final artistSeparators = <String>{'feat.', 'ft.', '&', ',', '—'}.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromPrefs();
  }

  // ── Scan ──────────────────────────────────────────────────────────

  Future<void> scanLibrary({bool force = false}) async {
    if (isScanning.value) return;
    isScanning.value = true;

    final prefs = await SharedPreferences.getInstance();

    // Listen to progress
    final sub = IndexerService.inst.progress.listen((p) {
      scanPhase.value    = p.phase;
      scanProgress.value = p.fraction;
    });

    try {
      final found = await IndexerService.inst.scanAll(
        checkedFolders: checkedFolders,
        excludedFolders: excludedPaths.toList(),
      );

      if (found.isEmpty && !force) {
        isScanning.value = false;
        sub.cancel();
        return;
      }

      // Restore ratings and loved state
      final existing = <String, Track>{for (final t in tracks) t.path: t};
      for (final t in found) {
        final old = existing[t.path];
        if (old != null) {
          t.rating = old.rating;
          t.plays  = old.plays;
          t.loved  = old.loved;
          t.lastPlayed = old.lastPlayed;
        } else if (ratings.containsKey(t.path)) {
          t.rating = ratings[t.path]!;
          t.loved  = lovedPaths.contains(t.path);
        }
      }

      tracks.value = found;
      _buildDerivedMaps();
      await _saveTracks();
      await prefs.setBool(kPrefScannedOnce, true);

    } finally {
      isScanning.value = false;
      sub.cancel();
    }
  }

  void _buildDerivedMaps() {
    final newAlbums   = <String, List<Track>>{};
    final newArtists  = <String, List<Track>>{};
    final newFolders  = <String, List<Track>>{};

    for (final t in tracks) {
      // Group by album
      newAlbums.putIfAbsent(t.album, () => []).add(t);
      // Group by primary artist (split "Artist feat. X" like Namida)
      final primaryArtist = _primaryArtist(t.artist);
      newArtists.putIfAbsent(primaryArtist, () => []).add(t);
      // Group by folder
      newFolders.putIfAbsent(t.folder, () => []).add(t);
    }

    albums.value  = newAlbums;
    artists.value = newArtists;
    folders.value = newFolders;
  }

  String _primaryArtist(String artist) {
    if (artistSeparators.isEmpty) return artist.trim();
    // Escape each separator for regex and join with |
    final escaped = artistSeparators.map((s) => RegExp.escape(s)).join('|');
    final pattern = RegExp('\\s*($escaped)\\s*', caseSensitive: false);
    return artist.split(pattern).first.trim();
  }

  /// Split artist string into all constituent artists using active separators.
  List<String> splitArtists(String artist) {
    if (artistSeparators.isEmpty) return [artist.trim()];
    final escaped = artistSeparators.map((s) => RegExp.escape(s)).join('|');
    final pattern = RegExp('\\s*($escaped)\\s*', caseSensitive: false);
    return artist.split(pattern).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Update separators, persist, and rebuild derived maps.
  Future<void> updateArtistSeparators(Set<String> seps) async {
    artistSeparators..clear()..addAll(seps);
    _buildDerivedMaps();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefArtistSeparators, seps.toList());
  }

  // ── Track stats ───────────────────────────────────────────────────

  Future<void> setRating(String path, int rating) async {
    ratings[path] = rating.clamp(0, 100);
    final track = tracks.firstWhereOrNull((t) => t.path == path);
    if (track != null) track.rating = rating;
    await _saveRatings();
  }

  Future<void> toggleLoved(String path) async {
    final track = tracks.firstWhereOrNull((t) => t.path == path);
    if (track == null) return;
    track.loved = !track.loved;
    track.loved ? lovedPaths.add(path) : lovedPaths.remove(path);
    await _saveRatings();
    tracks.refresh();
  }

  Future<void> incrementPlayCount(String path) async {
    final track = tracks.firstWhereOrNull((t) => t.path == path);
    if (track == null) return;
    track.plays++;
    track.lastPlayed = DateTime.now().millisecondsSinceEpoch;
    tracks.refresh();
    await _saveTracks();
  }

  // ── Bulk metadata edit ────────────────────────────────────────────
  /// Apply shared field changes to many tracks. Only non-null fields written.
  /// Returns count of files successfully tagged. Rebuilds Track objects so
  /// derived album/artist maps refresh.
  Future<int> bulkEditTags(
    List<String> paths, {
    String? album,
    String? albumArtist,
    String? artist,
    String? genre,
    int? year,
  }) async {
    final tags = <String, String>{};
    if (album != null && album.isNotEmpty) tags['album'] = album;
    if (albumArtist != null && albumArtist.isNotEmpty) tags['albumArtist'] = albumArtist;
    if (artist != null && artist.isNotEmpty) tags['artist'] = artist;
    if (genre != null && genre.isNotEmpty) tags['genre'] = genre;
    if (year != null && year > 0) tags['year'] = '$year';
    if (tags.isEmpty) return 0;

    int ok = 0;
    for (final p in paths) {
      final idx = tracks.indexWhere((t) => t.path == p);
      if (idx < 0) continue;
      final t = tracks[idx];
      final fsPath = t.filePath.isNotEmpty ? t.filePath : t.path;
      final wrote = await TagWriterService.inst.writeTags(fsPath, tags);
      if (!wrote) continue;
      tracks[idx] = t.copyWith(
        album: album, albumArtist: albumArtist, artist: artist,
        genre: genre, year: year,
      );
      ok++;
    }
    if (ok > 0) {
      _buildDerivedMaps();
      tracks.refresh();
      await _saveTracks();
    }
    return ok;
  }

  // ── Follow artists ────────────────────────────────────────────────

  bool isFollowing(String name) => followedArtists.contains(name.toLowerCase());

  Future<void> toggleFollowArtist(String name) async {
    final key = name.toLowerCase();
    if (followedArtists.contains(key)) {
      followedArtists.remove(key);
    } else {
      followedArtists.add(key);
    }
    await _saveFollowedArtists();
  }

  Future<void> _saveFollowedArtists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefFollowedArtists, followedArtists.toList());
  }

  // ── Exclusion ─────────────────────────────────────────────────────

  Future<void> excludeTrack(String path) async {
    excludedPaths.add(path);
    tracks.removeWhere((t) => t.path == path);
    _buildDerivedMaps();
    await _saveExcluded();
  }

  // ── Playlists ─────────────────────────────────────────────────────

  Future<Playlist> createPlaylist(String name) async {
    final pl = Playlist(id: DateTime.now().millisecondsSinceEpoch, name: name);
    playlists.add(pl);
    await _savePlaylists();
    return pl;
  }

  Future<Playlist> createSmartPlaylist(String name, SmartRules rules, {String icon = 'playlist_play', String color = '#A78BFA'}) async {
    final pl = Playlist(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name, smart: true, rules: rules,
      icon: icon, color: color,
    );
    playlists.add(pl);
    await _savePlaylists();
    return pl;
  }

  Future<void> updateSmartPlaylist(int id, String name, SmartRules rules, {String? icon, String? color}) async {
    final idx = playlists.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final old = playlists[idx];
    playlists[idx] = Playlist(
      id: old.id, name: name, smart: true, rules: rules,
      icon: icon ?? old.icon, color: color ?? old.color,
      createdAt: old.createdAt,
    );
    playlists.refresh();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(int id) async {
    playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
  }

  Future<void> renamePlaylist(int id, String name) async {
    final pl = playlists.firstWhereOrNull((p) => p.id == id);
    if (pl == null) return;
    pl.name = name;
    playlists.refresh();
    await _savePlaylists();
  }

  Future<void> addToPlaylist(int playlistId, String trackPath) async {
    final pl = playlists.firstWhereOrNull((p) => p.id == playlistId);
    if (pl == null || pl.trackPaths.contains(trackPath)) return;
    pl.trackPaths.add(trackPath);
    playlists.refresh();
    await _savePlaylists();
  }

  Future<void> removeFromPlaylist(int playlistId, String trackPath) async {
    final pl = playlists.firstWhereOrNull((p) => p.id == playlistId);
    if (pl == null) return;
    pl.trackPaths.remove(trackPath);
    playlists.refresh();
    await _savePlaylists();
  }

  List<Track> playlistTracks(Playlist pl) {
    if (pl.smart && pl.rules != null) {
      return evalSmart(pl.rules!, tracks.toList());
    }
    final map = <String, Track>{for (final t in tracks) t.path: t};
    return pl.trackPaths.map((p) => map[p]).whereType<Track>().toList();
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefPlaylists, jsonEncode(playlists.map((p) => p.toJson()).toList()));
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kPrefPlaylists);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        playlists.value = list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
  }

  // ── Persistence ───────────────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Load tracks — Namida startup fast-path
    final raw = prefs.getString(kPrefTracks);
    if (raw != null && raw.length > 1024) {
      try {
        final list = jsonDecode(raw) as List;
        tracks.value = list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
        _buildDerivedMaps();
      } catch (e) {
        debugPrint('Track load failed: $e');
      }
    }

    // Load ratings
    final rawRatings = prefs.getString(kPrefRatings);
    if (rawRatings != null) {
      try {
        final map = jsonDecode(rawRatings) as Map<String, dynamic>;
        ratings.value = map.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    // Load artist separators
    final savedSeps = prefs.getStringList(kPrefArtistSeparators);
    if (savedSeps != null) { artistSeparators..clear()..addAll(savedSeps); }

    // Load excluded paths
    final excluded = prefs.getStringList(kPrefExcludedPaths) ?? [];
    excludedPaths..clear()..addAll(excluded);

    // Load checked folders
    final checked = prefs.getStringList(kPrefCheckedFolders) ?? [];
    checkedFolders.value = checked;

    // Load followed artists
    final followed = prefs.getStringList(kPrefFollowedArtists) ?? [];
    followedArtists..clear()..addAll(followed);

    await _loadPlaylists();

    // Auto-scan on first launch
    final scannedOnce = prefs.getBool(kPrefScannedOnce) ?? false;
    if (!scannedOnce) {
      Future.delayed(const Duration(seconds: 2), () => scanLibrary());
    }
  }

  Future<void> _saveTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(tracks.map((t) => t.toJson()).toList());
    await prefs.setString(kPrefTracks, json);
  }

  Future<void> _saveRatings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefRatings, jsonEncode(ratings));
  }

  Future<void> _saveExcluded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefExcludedPaths, excludedPaths.toList());
  }

  Future<void> saveCheckedFolders(List<String> folders) async {
    checkedFolders.value = folders;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefCheckedFolders, folders);
  }
}
