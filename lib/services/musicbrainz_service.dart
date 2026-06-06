import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lightweight MusicBrainz + Cover Art Archive client.
class MusicBrainzService {
  MusicBrainzService._();
  static final inst = MusicBrainzService._();

  static const _base   = 'https://musicbrainz.org/ws/2';
  static const _ua     = 'Auradec/1.0 (auradec@example.com)';
  static const _fmt    = '&fmt=json';

  // ── Artist search ─────────────────────────────────────────────────────────

  Future<List<MbArtist>> searchArtist(String name) async {
    final url = '$_base/artist?query=${Uri.encodeComponent(name)}&limit=5$_fmt';
    final res  = await _get(url);
    if (res == null) return [];
    final list = (res['artists'] as List? ?? []);
    return list.map((e) => MbArtist.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<MbArtistDetail?> fetchArtist(String mbid) async {
    final url = '$_base/artist/$mbid?inc=tags+url-rels+ratings$_fmt';
    final res  = await _get(url);
    if (res == null) return null;
    return MbArtistDetail.fromJson(res);
  }

  // ── Release search ────────────────────────────────────────────────────────

  Future<List<MbRelease>> searchRelease(String album, String artist) async {
    final q   = 'release:$album AND artist:$artist';
    final url = '$_base/release?query=${Uri.encodeComponent(q)}&limit=5$_fmt';
    final res  = await _get(url);
    if (res == null) return [];
    return ((res['releases'] as List?) ?? [])
        .map((e) => MbRelease.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Recording (track) search ──────────────────────────────────────────────

  Future<List<MbRecording>> searchRecording(String title, String artist) async {
    final q   = 'recording:$title AND artist:$artist';
    final url = '$_base/recording?query=${Uri.encodeComponent(q)}&limit=5$_fmt';
    final res  = await _get(url);
    if (res == null) return [];
    return ((res['recordings'] as List?) ?? [])
        .map((e) => MbRecording.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Release track listing ─────────────────────────────────────────────────

  Future<List<MbTrack>> fetchReleaseTracks(String releaseMbid) async {
    final url = '$_base/release/$releaseMbid?inc=recordings$_fmt';
    final res  = await _get(url);
    if (res == null) return [];
    final media = (res['media'] as List?) ?? [];
    final tracks = <MbTrack>[];
    for (final m in media) {
      final tl = (m['tracks'] as List?) ?? [];
      for (final t in tl) {
        tracks.add(MbTrack.fromJson(t as Map<String, dynamic>,
            discNumber: (m['position'] as int?) ?? 1));
      }
    }
    return tracks;
  }

  // ── Cover Art ─────────────────────────────────────────────────────────────

  String coverArtUrl(String releaseMbid) =>
      'https://coverartarchive.org/release/$releaseMbid/front-250';

  /// Release-group front cover (CAA). More likely to resolve than per-release.
  String releaseGroupCoverUrl(String rgMbid, {int size = 250}) =>
      'https://coverartarchive.org/release-group/$rgMbid/front-$size';

  /// Download cover art as bytes (JPEG). Returns null on failure.
  Future<List<int>?> fetchCoverArtBytes(String releaseMbid) async {
    final url = 'https://coverartarchive.org/release/$releaseMbid/front';
    try {
      final res = await http.get(Uri.parse(url),
          headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ── Lyrics (LRCLib) ───────────────────────────────────────────────────────

  Future<String?> fetchLyricsPlain(String title, String artist) async {
    try {
      final url = 'https://lrclib.net/api/search?q=${Uri.encodeComponent("$title $artist")}';
      final res = await http.get(Uri.parse(url),
          headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List?;
      if (list == null || list.isEmpty) return null;
      // Pick first result with plain lyrics
      for (final item in list) {
        final plain = (item as Map)['plainLyrics'] as String?;
        if (plain != null && plain.trim().isNotEmpty) return plain.trim();
      }
    } catch (_) {}
    return null;
  }

  // ── Tagger search (multi-field, scored) ───────────────────────────────────

  Future<List<MbSearchResult>> searchForTagger({
    String? title,
    String? artist,
    String? album,
    String? year,
    String? trackNumber,
    int limit = 12,
  }) async {
    if (title == null && artist == null && album == null) return [];

    // Build Lucene query (raw — encoded once below)
    final parts = <String>[];
    if (title?.isNotEmpty == true)  parts.add('recording:${title!}');
    if (artist?.isNotEmpty == true) parts.add('artist:${artist!}');
    if (album?.isNotEmpty == true)  parts.add('release:${album!}');
    if (year?.isNotEmpty == true)   parts.add('date:${year!}');

    final q   = parts.join(' AND ');
    // inc: artist-credits for artist names, releases for album/date,
    // tags+genres for genre enrichment
    final url = '$_base/recording?query=${Uri.encodeQueryComponent(q)}&limit=$limit'
        '&inc=artist-credits%2Breleases%2Btags%2Bgenres$_fmt';
    final res  = await _get(url);
    if (res == null) return [];

    final recordings = (res['recordings'] as List?) ?? [];
    final results = <MbSearchResult>[];

    for (final r in recordings) {
      final rec     = r as Map<String, dynamic>;
      final mbScore = int.tryParse(rec['score']?.toString() ?? '0') ?? 0;

      // Artist credits
      final credits = (rec['artist-credit'] as List?) ?? [];
      final mbArtist = credits.map((a) {
        if (a is Map) {
          final joinphrase = (a['joinphrase'] as String?) ?? '';
          final name = (a['name'] as String?)
              ?? ((a['artist'] as Map?)?['name'] as String?) ?? '';
          return '$name$joinphrase';
        }
        return '';
      }).join('').trim();

      // Pick best release (official, or first)
      final releases = (rec['releases'] as List?) ?? [];
      Map<String, dynamic> rel = {};
      for (final rv in releases) {
        final status = (rv as Map)['status'] as String? ?? '';
        if (status.toLowerCase() == 'official') { rel = rv.cast(); break; }
      }
      if (rel.isEmpty && releases.isNotEmpty) rel = (releases.first as Map).cast();

      final mbTitle  = (rec['title'] as String?) ?? '';
      final mbAlbum  = (rel['title'] as String?) ?? '';
      final rawDate  = (rel['date'] as String?) ?? '';
      final mbYear   = rawDate.length >= 4 ? rawDate.substring(0, 4) : '';
      final releaseMbid = (rel['id'] as String?) ?? '';
      final releaseGroupMbid = ((rel['release-group'] as Map?)?['id'] as String?) ?? '';

      // Track number from release's track map
      String mbTrack = '';
      if (releases.isNotEmpty) {
        final trackMap = (releases.first as Map)['track'] as Map?;
        mbTrack = trackMap?['number']?.toString() ?? '';
      }

      // Genres: merge MB curated genres + community tags
      final genreList = <String>{};
      for (final g in (rec['genres'] as List?) ?? []) {
        final name = (g as Map)['name'] as String? ?? '';
        if (name.isNotEmpty) genreList.add(name.toLowerCase());
      }
      // Sort community tags by count, take top 5
      final tagList = ((rec['tags'] as List?) ?? [])
        ..sort((a, b) => ((b as Map)['count'] as int? ?? 0)
            .compareTo((a as Map)['count'] as int? ?? 0));
      for (final t in tagList.take(5)) {
        final name = (t as Map)['name'] as String? ?? '';
        if (name.isNotEmpty) genreList.add(name.toLowerCase());
      }

      // Composite score: MB's own score (0-100) weighted 65% + field similarity 35%
      final mbNorm = mbScore / 100.0;
      final fieldSim = _fieldSim(title, mbTitle) * 0.5
          + _fieldSim(artist, mbArtist) * 0.3
          + _fieldSim(album, mbAlbum)   * 0.15
          + _fieldSim(year, mbYear)     * 0.05;
      final composite = mbNorm * 0.65 + fieldSim * 0.35;

      results.add(MbSearchResult(
        recordingId: (rec['id'] as String?) ?? '',
        releaseId: releaseMbid,
        releaseGroupId: releaseGroupMbid,
        title: mbTitle,
        artist: mbArtist,
        album: mbAlbum,
        year: mbYear,
        trackNumber: mbTrack,
        score: composite,
        mbScore: mbScore,
        genres: genreList.take(6).toList(),
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Field similarity: 0.0–1.0. Null/empty query = 0.5 neutral.
  static double _fieldSim(String? query, String target) {
    if (query == null || query.isEmpty) return 0.5;
    if (target.isEmpty) return 0.0;
    final q = query.toLowerCase().trim();
    final t = target.toLowerCase().trim();
    if (t == q) return 1.0;
    if (t.contains(q) || q.contains(t)) return 0.85;
    final qW = q.split(RegExp(r'\s+')).toSet();
    final tW = t.split(RegExp(r'\s+')).toSet();
    final common = qW.intersection(tW).length;
    if (common > 0) return common / (qW.length + tW.length - common) * 0.8 + 0.1;
    final qC = q.split('').toSet();
    final tC = t.split('').toSet();
    final charCommon = qC.intersection(tC).length;
    return charCommon / (qC.length + tC.length - charCommon) * 0.5;
  }

  // Keep old name for any callers
  static double _score(String? query, String target) => _fieldSim(query, target);

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _get(String url) async {
    try {
      final res = await http.get(Uri.parse(url),
          headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class MbArtist {
  final String id;
  final String name;
  final String? disambiguation;
  final String? country;
  final int score;
  MbArtist({required this.id, required this.name, this.disambiguation, this.country, this.score = 0});
  factory MbArtist.fromJson(Map<String, dynamic> j) => MbArtist(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    disambiguation: j['disambiguation'],
    country: j['country'],
    score: int.tryParse(j['score']?.toString() ?? '0') ?? 0,
  );
}

class MbArtistDetail {
  final String id;
  final String name;
  final String? disambiguation;
  final String? country;
  final String? type;
  final List<String> tags;
  final String? beginDate;
  final String? endDate;
  final List<MbUrl> urls;
  MbArtistDetail({required this.id, required this.name, this.disambiguation,
    this.country, this.type, this.tags = const [], this.beginDate,
    this.endDate, this.urls = const []});

  factory MbArtistDetail.fromJson(Map<String, dynamic> j) {
    final tags = ((j['tags'] as List?) ?? [])
        .map((t) => t['name']?.toString() ?? '').where((t) => t.isNotEmpty).toList();
    final lbs = ((j['life-span'] as Map?) ?? {});
    final urls = ((j['relations'] as List?) ?? [])
        .where((r) => r['type'] == 'official homepage' || r['type'] == 'social network' || r['type'] == 'streaming music')
        .map((r) => MbUrl(type: r['type'] ?? '', url: (r['url'] as Map?)?['resource'] ?? ''))
        .where((u) => u.url.isNotEmpty)
        .toList();
    return MbArtistDetail(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      disambiguation: j['disambiguation'],
      country: j['country'],
      type: j['type'],
      tags: tags.cast<String>(),
      beginDate: lbs['begin'],
      endDate: lbs['end'],
      urls: urls,
    );
  }
}

class MbUrl { final String type; final String url; const MbUrl({required this.type, required this.url}); }

class MbRelease {
  final String id;
  final String title;
  final String? date;
  final String? country;
  final String? status;
  MbRelease({required this.id, required this.title, this.date, this.country, this.status});
  factory MbRelease.fromJson(Map<String, dynamic> j) => MbRelease(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    date: j['date'],
    country: j['country'],
    status: j['status'],
  );
}

class MbRecording {
  final String id;
  final String title;
  final int? lengthMs;
  final String? firstRelease;
  MbRecording({required this.id, required this.title, this.lengthMs, this.firstRelease});
  factory MbRecording.fromJson(Map<String, dynamic> j) => MbRecording(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    lengthMs: j['length'] as int?,
    firstRelease: j['first-release-date'],
  );
}

class MbTrack {
  final String id;
  final String title;
  final int number;
  final int discNumber;
  final int? lengthMs;
  final String? recordingId;
  MbTrack({required this.id, required this.title, required this.number,
      required this.discNumber, this.lengthMs, this.recordingId});
  factory MbTrack.fromJson(Map<String, dynamic> j, {int discNumber = 1}) {
    final numStr = j['number']?.toString() ?? '0';
    return MbTrack(
      id: j['id'] ?? '',
      title: j['title'] ?? '',
      number: int.tryParse(numStr) ?? 0,
      discNumber: discNumber,
      lengthMs: j['length'] as int?,
      recordingId: (j['recording'] as Map?)?['id'] as String?,
    );
  }
  String get durationStr {
    if (lengthMs == null) return '';
    final s = lengthMs! ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class MbSearchResult {
  final String recordingId;
  final String releaseId;
  final String releaseGroupId;
  final String title;
  final String artist;
  final String album;
  final String year;
  final String trackNumber;
  final double score;        // 0.0–1.0 composite
  final int mbScore;         // MusicBrainz own score 0–100
  final List<String> genres; // from tags + genres arrays

  MbSearchResult({
    required this.recordingId,
    required this.releaseId,
    this.releaseGroupId = '',
    required this.title,
    required this.artist,
    required this.album,
    required this.year,
    required this.trackNumber,
    required this.score,
    required this.mbScore,
    this.genres = const [],
  });

  /// Percentage string e.g. "87%"
  String get pct => '${(score * 100).round()}%';
}
