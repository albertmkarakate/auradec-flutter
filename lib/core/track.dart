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

class Playlist {
  final int id;
  String name;
  final List<String> trackPaths;
  final int createdAt;

  Playlist({required this.id, required this.name, List<String>? trackPaths, int? createdAt})
      : trackPaths = trackPaths ?? [],
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'trackPaths': trackPaths, 'createdAt': createdAt,
  };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
    id: j['id'] ?? 0,
    name: j['name'] ?? 'Untitled',
    trackPaths: (j['trackPaths'] as List?)?.cast<String>() ?? [],
    createdAt: j['createdAt'] ?? 0,
  );

  @override
  bool operator ==(Object other) => other is Playlist && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
