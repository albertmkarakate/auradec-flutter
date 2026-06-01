import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';

class GenreDetailScreen extends StatelessWidget {
  final String genre;
  final Color color;
  const GenreDetailScreen({super.key, required this.genre, required this.color});

  @override
  Widget build(BuildContext context) {
    final tracks = LibraryController.inst.tracks
        .where((t) => t.genre.toLowerCase().contains(genre.toLowerCase()))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    final totalMin = tracks.fold(0, (s, t) => s + t.durationMs) ~/ 60000;

    return Scaffold(
      backgroundColor: kBg0,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: kBg0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kFg1),
            onPressed: () => Get.back(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            title: Text(
              genre,
              style: const TextStyle(
                color: kFg1,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Syne',
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withAlpha(180),
                    color.withAlpha(60),
                    kBg0,
                  ],
                ),
              ),
            ),
          ),
        ),
        if (tracks.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, color: kFg3, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No tracks found for "$genre"',
                    style: const TextStyle(color: kFg2, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, children: [
                    _chip('${tracks.length} tracks'),
                    _chip('${totalMin}m'),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play all'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          PlayerController.inst.playTrack(tracks.first, queue: tracks);
                          Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.shuffle, color: kFg2),
                      style: IconButton.styleFrom(
                        backgroundColor: kBg2,
                        shape: const CircleBorder(),
                      ),
                      onPressed: () {
                        final shuffled = [...tracks]..shuffle();
                        PlayerController.inst.playTrack(shuffled.first, queue: shuffled);
                        Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => TrackTile(
                track: tracks[i],
                onTap: () {
                  PlayerController.inst.playTrack(tracks[i], queue: tracks);
                  Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
                },
              ),
              childCount: tracks.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ]),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: kBg2,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: kBorder),
    ),
    child: Text(text, style: const TextStyle(color: kFg2, fontSize: 10, letterSpacing: 0.5)),
  );
}
