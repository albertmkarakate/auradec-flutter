import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistName;
  const ArtistDetailScreen({super.key, required this.artistName});
  @override State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  String? _bio;
  bool _bioLoading = true;

  @override
  void initState() { super.initState(); _fetchBio(); }

  Future<void> _fetchBio() async {
    try {
      final res = await http.get(Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(widget.artistName)}'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['type'] != 'disambiguation' && j['extract'] != null) {
          setState(() { _bio = j['extract'] as String; });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _bioLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lib     = LibraryController.inst;
      final tracks  = lib.artists[widget.artistName] ?? [];
      final albums  = lib.albums.entries.where((e) => e.value.any((t) => t.artist.contains(widget.artistName))).toList();

      return Scaffold(
        backgroundColor: kBg0,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 200, pinned: true, backgroundColor: kBg0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: RadialGradient(
                  center: Alignment.topCenter, radius: 1.5,
                  colors: [kBrandOrange.withAlpha(60), kBg0],
                )),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBrandOrange.withAlpha(100), width: 2)),
                    child: ClipOval(child: AlbumArt(
                      artUri: tracks.isNotEmpty ? tracks.first.artUri : null,
                      filePath: tracks.isNotEmpty ? tracks.first.filePath : null,
                      seed: widget.artistName, size: 80, radius: 40,
                    )),
                  ),
                  const SizedBox(height: 10),
                ]),
              ),
            ),
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: kFg1), onPressed: () => Get.back()),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(children: [
              Text(widget.artistName, style: const TextStyle(color: kFg1, fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'Syne'), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              if (tracks.isNotEmpty) Text('${tracks.length} tracks · ${albums.length} albums', style: const TextStyle(color: kFg2, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow), label: const Text('Play all'),
                  style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: tracks.isEmpty ? null : () { PlayerController.inst.playTrack(tracks.first, queue: tracks); Get.to(() => const NowPlayingScreen()); },
                )),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.shuffle, color: kFg2), style: IconButton.styleFrom(backgroundColor: kBg2, shape: const CircleBorder()),
                  onPressed: tracks.isEmpty ? null : () { final s = [...tracks]..shuffle(); PlayerController.inst.playTrack(s.first, queue: s); Get.to(() => const NowPlayingScreen()); }),
              ]),
              const SizedBox(height: 12),
              // Bio
              if (_bioLoading) const LinearProgressIndicator(color: kBrandOrange, backgroundColor: kBg2)
              else if (_bio != null) Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kBg1, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                child: Text(_bio!.length > 400 ? '${_bio!.substring(0, 400)}…' : _bio!, style: const TextStyle(color: kFg2, fontSize: 12, height: 1.6)),
              ),
              const SizedBox(height: 16),
            ]),
          )),
          if (albums.isNotEmpty) ...[
            SliverToBoxAdapter(child: _sectionHead('Albums')),
            SliverToBoxAdapter(child: SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: albums.length,
                itemBuilder: (_, i) {
                  final name = albums[i].key; final trks = albums[i].value;
                  return GestureDetector(
                    onTap: () => Get.to(() => AlbumDetailScreen(albumName: name, tracks: trks)),
                    child: Container(width: 110, margin: const EdgeInsets.only(right: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AlbumArt(artUri: trks.first.artUri, filePath: trks.first.filePath, seed: name, size: 110, radius: 10),
                        const SizedBox(height: 5),
                        Text(name, style: const TextStyle(color: kFg1, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  );
                },
              ),
            )),
          ],
          SliverToBoxAdapter(child: _sectionHead('Top tracks')),
          SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => TrackTile(track: tracks[i], onTap: () { PlayerController.inst.playTrack(tracks[i], queue: tracks); Get.to(() => const NowPlayingScreen()); }),
            childCount: tracks.length,
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      );
    });
  }

  Widget _sectionHead(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(label.toUpperCase(), style: const TextStyle(color: kBrandGold, fontSize: 9, letterSpacing: 2.5, fontFamily: 'Barlow')),
  );
}
