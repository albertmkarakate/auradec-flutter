import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/player_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumName;
  final List<Track> tracks;
  const AlbumDetailScreen({super.key, required this.albumName, required this.tracks});

  @override
  Widget build(BuildContext context) {
    final sorted = [...tracks]..sort((a, b) => a.trackNo.compareTo(b.trackNo));
    final totalMin = sorted.fold(0, (s, t) => s + t.durationMs) ~/ 60000;
    final artist = sorted.first.albumArtist.isNotEmpty ? sorted.first.albumArtist : sorted.first.artist;

    return Scaffold(
      backgroundColor: kBg0,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 260, pinned: true,
          backgroundColor: kBg0,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              AlbumArt(artUri: sorted.first.artUri, seed: albumName, size: double.infinity, radius: 0),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, kBg0.withAlpha(230), kBg0],
              ))),
            ]),
          ),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kFg1), onPressed: () => Get.back()),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ALBUM', style: TextStyle(color: kBrandOrange, fontSize: 8, letterSpacing: 3)),
            const SizedBox(height: 4),
            Text(albumName, style: const TextStyle(color: kFg1, fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            const SizedBox(height: 4),
            Text(artist, style: const TextStyle(color: kFg2, fontSize: 14)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              if (sorted.first.year > 0) _chip('${sorted.first.year}'),
              _chip('${sorted.length} tracks'),
              _chip('${totalMin}m'),
              if (sorted.first.genre.isNotEmpty) _chip(sorted.first.genre),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow), label: const Text('Play'),
                style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () { PlayerController.inst.playTrack(sorted.first, queue: sorted); Get.to(() => const NowPlayingScreen()); },
              )),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.shuffle, color: kFg2),
                style: IconButton.styleFrom(backgroundColor: kBg2, shape: const CircleBorder()),
                onPressed: () {
                  final s = [...sorted]..shuffle();
                  PlayerController.inst.playTrack(s.first, queue: s);
                  Get.to(() => const NowPlayingScreen());
                },
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.more_vert, color: kFg2),
                style: IconButton.styleFrom(backgroundColor: kBg2, shape: const CircleBorder()),
                onPressed: () {},
              ),
            ]),
          ]),
        )),
        SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) => TrackTile(
            track: sorted[i],
            showNumber: true,
            onTap: () { PlayerController.inst.playTrack(sorted[i], queue: sorted); Get.to(() => const NowPlayingScreen()); },
          ),
          childCount: sorted.length,
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(999), border: Border.all(color: kBorder)),
    child: Text(text, style: const TextStyle(color: kFg2, fontSize: 10, letterSpacing: 0.5)),
  );
}
