import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Last.fm REST API client.
/// API key stored in SharedPreferences under 'api_key_lastfm'.
/// Get a free key at https://www.last.fm/api/account/create
class LastFmService {
  LastFmService._();
  static final inst = LastFmService._();

  static const _base = 'https://ws.audioscrobbler.com/2.0/';
  static const _ua   = 'Auradec/1.0 (auradec@example.com)';

  // ── Key management ────────────────────────────────────────────────────────

  Future<String?> getApiKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('api_key_lastfm');
  }

  Future<void> setApiKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('api_key_lastfm', key);
  }

  // ── Track info ────────────────────────────────────────────────────────────

  /// Returns track metadata from Last.fm including tags and album images.
  Future<LastFmTrackInfo?> trackInfo(String artist, String track) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) return null;
    final url = Uri.parse(_base).replace(queryParameters: {
      'method': 'track.getInfo',
      'artist': artist,
      'track':  track,
      'api_key': key,
      'format': 'json',
      'autocorrect': '1',
    });
    final d = await _get(url.toString());
    if (d == null || d['track'] == null) return null;
    final t = d['track'] as Map<String, dynamic>;

    final tags = ((t['toptags']?['tag'] as List?) ?? [])
        .map((tag) => (tag['name'] as String? ?? '').toLowerCase())
        .where((s) => s.isNotEmpty)
        .take(8)
        .toList();

    final wiki = ((t['wiki']?['summary'] as String?) ?? '')
        .replaceAll(RegExp(r'<[^>]*>'), '').trim();

    // Album images (nested in track.album)
    final albumImgs = ((t['album']?['image'] as List?) ?? [])
        .map((img) => img['#text'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final albumName = t['album']?['title'] as String? ?? '';
    final mbid      = t['mbid'] as String? ?? '';

    return LastFmTrackInfo(
      tags: tags,
      wiki: wiki.isNotEmpty ? wiki : null,
      albumImages: albumImgs,
      albumName: albumName,
      mbid: mbid,
    );
  }

  // ── Album info ────────────────────────────────────────────────────────────

  /// Returns album metadata including images and tags.
  Future<LastFmAlbumInfo?> albumInfo(String artist, String album) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) return null;
    final url = Uri.parse(_base).replace(queryParameters: {
      'method': 'album.getInfo',
      'artist': artist,
      'album':  album,
      'api_key': key,
      'format': 'json',
      'autocorrect': '1',
    });
    final d = await _get(url.toString());
    if (d == null || d['album'] == null) return null;
    final a = d['album'] as Map<String, dynamic>;

    // Images: extralarge or large preferred
    final images = ((a['image'] as List?) ?? [])
        .map((img) => img['#text'] as String? ?? '')
        .where((s) => s.isNotEmpty && !s.contains('2a96cbd8b46e442fc41c2b86b821562f'))
        .toList();

    final tags = ((a['tags']?['tag'] as List?) ?? [])
        .map((tag) => (tag['name'] as String? ?? '').toLowerCase())
        .where((s) => s.isNotEmpty)
        .take(8)
        .toList();

    final wiki = ((a['wiki']?['summary'] as String?) ?? '')
        .replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final totalTracks = (a['tracks']?['track'] as List?)?.length ?? 0;

    return LastFmAlbumInfo(
      images: images,
      tags: tags,
      wiki: wiki.isNotEmpty ? wiki : null,
      totalTracks: totalTracks,
    );
  }

  // ── Album search ──────────────────────────────────────────────────────────

  /// Search albums by name, returns image URLs.
  Future<List<LastFmAlbumMatch>> albumSearch(String album) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) return [];
    final url = Uri.parse(_base).replace(queryParameters: {
      'method': 'album.search',
      'album':  album,
      'api_key': key,
      'format': 'json',
      'limit': '10',
    });
    final d = await _get(url.toString());
    if (d == null) return [];
    final matches = (d['results']?['albummatches']?['album'] as List?) ?? [];
    return matches.map((m) {
      final imgs = (m['image'] as List? ?? [])
          .map((i) => i['#text'] as String? ?? '')
          .where((s) => s.isNotEmpty && !s.contains('2a96cbd8b46e442fc41c2b86b821562f'))
          .toList();
      return LastFmAlbumMatch(
        name:   m['name'] as String? ?? '',
        artist: m['artist'] as String? ?? '',
        images: imgs,
      );
    }).where((m) => m.images.isNotEmpty).toList();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final res = await http.get(Uri.parse(url),
          headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class LastFmTrackInfo {
  final List<String> tags;
  final String? wiki;
  final List<String> albumImages;
  final String albumName;
  final String mbid;
  const LastFmTrackInfo({
    required this.tags,
    this.wiki,
    required this.albumImages,
    required this.albumName,
    required this.mbid,
  });
}

class LastFmAlbumInfo {
  final List<String> images;
  final List<String> tags;
  final String? wiki;
  final int totalTracks;
  const LastFmAlbumInfo({
    required this.images,
    required this.tags,
    this.wiki,
    required this.totalTracks,
  });
}

class LastFmAlbumMatch {
  final String name;
  final String artist;
  final List<String> images;
  const LastFmAlbumMatch({required this.name, required this.artist, required this.images});
}
