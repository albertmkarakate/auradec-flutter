import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/track.dart';

class Playlist {
  final String id;
  String name;
  List<String> trackPaths;
  Playlist({required this.id, required this.name, required this.trackPaths});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'trackPaths': trackPaths};
  factory Playlist.fromJson(Map<String, dynamic> j) =>
      Playlist(id: j['id'], name: j['name'], trackPaths: List<String>.from(j['trackPaths'] ?? []));
}

class PlaylistController extends GetxController {
  static PlaylistController get inst => Get.find();

  final playlists = <Playlist>[].obs;

  @override
  void onInit() { super.onInit(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('auradec_playlists_v2');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        playlists.value = list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auradec_playlists_v2', jsonEncode(playlists.map((p) => p.toJson()).toList()));
  }

  Future<Playlist> create(String name) async {
    final pl = Playlist(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, trackPaths: []);
    playlists.add(pl);
    await _save();
    return pl;
  }

  Future<void> addTrack(String playlistId, String trackPath) async {
    final pl = playlists.firstWhereOrNull((p) => p.id == playlistId);
    if (pl == null || pl.trackPaths.contains(trackPath)) return;
    pl.trackPaths.add(trackPath);
    playlists.refresh();
    await _save();
  }

  Future<void> removeTrack(String playlistId, String trackPath) async {
    final pl = playlists.firstWhereOrNull((p) => p.id == playlistId);
    if (pl == null) return;
    pl.trackPaths.remove(trackPath);
    playlists.refresh();
    await _save();
  }

  Future<void> delete(String playlistId) async {
    playlists.removeWhere((p) => p.id == playlistId);
    await _save();
  }

  List<Track> tracksFor(String playlistId, List<Track> allTracks) {
    final pl = playlists.firstWhereOrNull((p) => p.id == playlistId);
    if (pl == null) return [];
    final map = {for (final t in allTracks) t.path: t};
    return pl.trackPaths.map((p) => map[p]).whereType<Track>().toList();
  }
}
