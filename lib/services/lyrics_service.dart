import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/track.dart';

class LyricLine { final double time; final String text; const LyricLine(this.time, this.text); }

class LyricsResult {
  final List<LyricLine> synced;
  final String plain;
  final String source;
  const LyricsResult({required this.synced, required this.plain, required this.source});
  bool get hasSynced => synced.isNotEmpty;
}

class LyricsService {
  static final LyricsService inst = LyricsService._();
  LyricsService._();

  final _cache = <String, LyricsResult?>{};

  Future<LyricsResult?> fetch(Track track) async {
    final key = '${track.artist}\0${track.title}';
    if (_cache.containsKey(key)) return _cache[key];
    final result = await _fetchLrclib(track) ?? await _fetchNetease(track);
    _cache[key] = result;
    return result;
  }

  Future<LyricsResult?> _fetchLrclib(Track track) async {
    try {
      final params = Uri(queryParameters: {
        'artist_name': track.artist, 'track_name': track.title,
        'album_name': track.album,
        if (track.durationMs > 0) 'duration': '${track.durationMs ~/ 1000}',
      });
      final res = await http.get(Uri.parse('https://lrclib.net/api/get?$params'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      if (d['error'] != null) return null;
      final synced = d['syncedLyrics'] != null ? _parseLrc(d['syncedLyrics'] as String) : <LyricLine>[];
      final plain  = d['plainLyrics'] as String? ?? '';
      if (synced.isEmpty && plain.isEmpty) return null;
      return LyricsResult(synced: synced, plain: plain, source: 'LRCLIB');
    } catch (_) { return null; }
  }

  Future<LyricsResult?> _fetchNetease(Track track) async {
    try {
      final q = '${track.artist} ${track.title}';
      final sr = await http.post(
        Uri.parse('https://music.163.com/api/search/pc'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Referer': 'https://music.163.com/'},
        body: 's=$q&type=1&limit=5&offset=0',
      ).timeout(const Duration(seconds: 6));
      if (sr.statusCode != 200) return null;
      final sd = jsonDecode(sr.body) as Map<String, dynamic>;
      final songs = (sd['result']?['songs'] as List?)?.cast<Map>();
      if (songs == null || songs.isEmpty) return null;
      final songId = songs[0]['id'];
      final lr = await http.get(
        Uri.parse('https://music.163.com/api/song/lyric?id=$songId&lv=1'),
        headers: {'Referer': 'https://music.163.com/'},
      ).timeout(const Duration(seconds: 6));
      if (lr.statusCode != 200) return null;
      final ld = jsonDecode(lr.body) as Map<String, dynamic>;
      final lrc = ld['lrc']?['lyric'] as String?;
      if (lrc == null) return null;
      final synced = _parseLrc(lrc);
      if (synced.isNotEmpty) return LyricsResult(synced: synced, plain: '', source: 'NetEase');
      return null;
    } catch (_) { return null; }
  }

  List<LyricLine> _parseLrc(String lrc) {
    final lines = <LyricLine>[];
    for (final line in lrc.split('\n')) {
      final m = RegExp(r'^\[(\d+):(\d{1,2}[.,]\d+)\](.*)').firstMatch(line);
      if (m == null) continue;
      final mins = int.parse(m.group(1)!);
      final secs = double.parse(m.group(2)!.replaceAll(',', '.'));
      final text = m.group(3)!.trim();
      lines.add(LyricLine(mins * 60 + secs, text));
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }
}
