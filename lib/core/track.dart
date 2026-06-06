/// Core track model — mirrors Namida's TrackExtended fields.
class Track {
  final String path;         // content:// URI for ExoPlayer
  final String filePath;    // absolute /storage/... path for metadata/art
  final String title;
  final String artist;
  final String albumArtist;
  final String album;
  final String genre;
  final int    year;
  final int    trackNo;
  final int    discNo;
  final int    durationMs;   // milliseconds
  final int    bitrate;      // kbps
  final int    sampleRate;   // Hz
  final int    fileSize;     // bytes
  final String codec;
  final bool   isLossless;
  final String? comment;
  String? artUri;  // content:// album art URI from MediaStore

  // Mutable stats (stored separately like Namida's two-DB design)
  int    rating;   // 0–100
  int    plays;
  int    lastPlayed;  // epoch ms
  bool   loved;

  Track({
    required this.path,
    this.filePath = '',
    required this.title,
    required this.artist,
    this.albumArtist = '',
    required this.album,
    this.genre = '',
    this.year = 0,
    this.trackNo = 0,
    this.discNo = 0,
    required this.durationMs,
    this.bitrate = 0,
    this.sampleRate = 44100,
    this.fileSize = 0,
    this.codec = 'MP3',
    this.isLossless = false,
    this.comment,
    this.rating = 0,
    this.plays = 0,
    this.lastPlayed = 0,
    this.loved = false,
  });

  Track copyWith({
    String? title, String? artist, String? albumArtist, String? album,
    String? genre, int? year, int? trackNo, int? discNo, String? comment,
  }) {
    final t = Track(
      path: path, filePath: filePath,
      title: title ?? this.title, artist: artist ?? this.artist,
      albumArtist: albumArtist ?? this.albumArtist, album: album ?? this.album,
      genre: genre ?? this.genre, year: year ?? this.year,
      trackNo: trackNo ?? this.trackNo, discNo: discNo ?? this.discNo,
      durationMs: durationMs, bitrate: bitrate, sampleRate: sampleRate,
      fileSize: fileSize, codec: codec, isLossless: isLossless,
      comment: comment ?? this.comment,
      rating: rating, plays: plays, lastPlayed: lastPlayed, loved: loved,
    );
    t.artUri = artUri;
    return t;
  }

  String get filename {
    final i = path.lastIndexOf('/');
    return i >= 0 ? path.substring(i + 1) : path;
  }

  String get folder {
    final i = path.lastIndexOf('/');
    return i >= 0 ? path.substring(0, i) : '/';
  }

  Duration get duration => Duration(milliseconds: durationMs);

  Map<String, dynamic> toJson() => {
    'path': path, 'filePath': filePath, 'title': title, 'artist': artist, 'albumArtist': albumArtist,
    'album': album, 'genre': genre, 'year': year, 'trackNo': trackNo, 'discNo': discNo,
    'durationMs': durationMs, 'bitrate': bitrate, 'sampleRate': sampleRate,
    'fileSize': fileSize, 'codec': codec, 'isLossless': isLossless, 'comment': comment,
    'rating': rating, 'plays': plays, 'lastPlayed': lastPlayed, 'loved': loved,
  };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
    path: j['path'] ?? '', filePath: j['filePath'] ?? '', title: j['title'] ?? 'Unknown',
    artist: j['artist'] ?? 'Unknown Artist', albumArtist: j['albumArtist'] ?? '',
    album: j['album'] ?? 'Unknown Album', genre: j['genre'] ?? '',
    year: j['year'] ?? 0, trackNo: j['trackNo'] ?? 0, discNo: j['discNo'] ?? 0,
    durationMs: j['durationMs'] ?? 0, bitrate: j['bitrate'] ?? 0,
    sampleRate: j['sampleRate'] ?? 44100, fileSize: j['fileSize'] ?? 0,
    codec: j['codec'] ?? 'MP3', isLossless: j['isLossless'] ?? false,
    comment: j['comment'], rating: j['rating'] ?? 0, plays: j['plays'] ?? 0,
    lastPlayed: j['lastPlayed'] ?? 0, loved: j['loved'] ?? false,
  );

  @override
  bool operator ==(Object other) => other is Track && other.path == path;
  @override
  int get hashCode => path.hashCode;
}

// ── Smart playlist models ─────────────────────────────────────────────────────

/// One filter condition: { field, op, value }
class SmartCondition {
  final String field; // rating | plays | durationSec | year | lastDays | genre | artist | album | title
  final String op;    // num: gte/lte/gt/lt/eq  text: contains/is/not/starts  days: within/before/never
  final String value;
  const SmartCondition({required this.field, required this.op, required this.value});

  Map<String, dynamic> toJson() => {'field': field, 'op': op, 'value': value};
  factory SmartCondition.fromJson(Map<String, dynamic> j) =>
      SmartCondition(field: j['field'] ?? '', op: j['op'] ?? '', value: j['value'] ?? '');
}

/// Top-level smart-playlist rule object.
class SmartRules {
  final String match;              // 'all' | 'any'
  final List<SmartCondition> conditions;
  final String sort;               // rating | plays | recent | added | duration | title

  const SmartRules({this.match = 'all', this.conditions = const [], this.sort = 'title'});

  Map<String, dynamic> toJson() => {
    'match': match,
    'conditions': conditions.map((c) => c.toJson()).toList(),
    'sort': sort,
  };
  factory SmartRules.fromJson(Map<String, dynamic> j) => SmartRules(
    match: j['match'] ?? 'all',
    conditions: ((j['conditions'] as List?) ?? [])
        .map((e) => SmartCondition.fromJson(e as Map<String, dynamic>)).toList(),
    sort: j['sort'] ?? 'title',
  );
}

// ── Playlist ──────────────────────────────────────────────────────────────────

class Playlist {
  final int id;
  String name;
  final List<String> trackPaths; // manual playlist paths (ignored when smart==true)
  final int createdAt;
  final bool smart;
  final SmartRules? rules;       // non-null iff smart==true
  final String icon;
  final String color;            // hex e.g. '#A78BFA'

  Playlist({
    required this.id,
    required this.name,
    List<String>? trackPaths,
    int? createdAt,
    this.smart = false,
    this.rules,
    this.icon = 'playlist_play',
    this.color = '#FF5C1A',
  })  : trackPaths = trackPaths ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'trackPaths': trackPaths, 'createdAt': createdAt,
    'smart': smart, 'rules': rules?.toJson(), 'icon': icon, 'color': color,
  };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
    id: j['id'] ?? 0,
    name: j['name'] ?? 'Untitled',
    trackPaths: (j['trackPaths'] as List?)?.cast<String>() ?? [],
    createdAt: j['createdAt'] ?? 0,
    smart: j['smart'] == true,
    rules: j['rules'] != null ? SmartRules.fromJson(j['rules'] as Map<String, dynamic>) : null,
    icon: j['icon'] ?? 'playlist_play',
    color: j['color'] ?? '#FF5C1A',
  );

  @override
  bool operator ==(Object other) => other is Playlist && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
