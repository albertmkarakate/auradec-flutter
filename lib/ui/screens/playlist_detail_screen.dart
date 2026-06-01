import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lib    = LibraryController.inst;
      final tracks = lib.playlistTracks(playlist);

      return Scaffold(
        backgroundColor: kBg0,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true, expandedHeight: 180, backgroundColor: kBg0,
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: kFg1), onPressed: () => Get.back()),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: kFg2),
                onPressed: () => _rename(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: kBrandCoral),
                onPressed: () => _delete(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                tracks.isNotEmpty
                    ? AlbumArt(artUri: tracks.first.artUri, filePath: tracks.first.filePath, seed: playlist.name, size: double.infinity, radius: 0)
                    : Container(color: kBg2),
                Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, kBg0.withAlpha(230), kBg0],
                ))),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PLAYLIST', style: TextStyle(color: kBrandOrange, fontSize: 8, letterSpacing: 3)),
              const SizedBox(height: 4),
              Text(playlist.name, style: const TextStyle(color: kFg1, fontSize: 26,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${tracks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 13)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: tracks.isEmpty ? null : () {
                    PlayerController.inst.playTrack(tracks.first, queue: tracks);
                    Get.to(() => const NowPlayingScreen());
                  },
                )),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.shuffle, color: kFg2),
                  style: IconButton.styleFrom(backgroundColor: kBg2, shape: const CircleBorder()),
                  onPressed: tracks.isEmpty ? null : () {
                    final s = [...tracks]..shuffle();
                    PlayerController.inst.playTrack(s.first, queue: s);
                    Get.to(() => const NowPlayingScreen());
                  },
                ),
              ]),
            ]),
          )),
          if (tracks.isEmpty)
            const SliverFillRemaining(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_music, color: kFg3, size: 48),
                SizedBox(height: 12),
                Text('No tracks yet', style: TextStyle(color: kFg2, fontSize: 14)),
                SizedBox(height: 4),
                Text('Long-press any track to add it here',
                    style: TextStyle(color: kFg3, fontSize: 11)),
              ],
            )))
          else
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => TrackTile(
                track: tracks[i],
                showNumber: true,
                onTap: () {
                  PlayerController.inst.playTrack(tracks[i], queue: tracks);
                  Get.to(() => const NowPlayingScreen());
                },
                trailingAction: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: kBrandCoral, size: 20),
                  onPressed: () => lib.removeFromPlaylist(playlist.id, tracks[i].path),
                ),
              ),
              childCount: tracks.length,
            )),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      );
    });
  }

  void _rename(BuildContext context) {
    final ctrl = TextEditingController(text: playlist.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBg1,
        title: const Text('Rename playlist', style: TextStyle(color: kFg1)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: kFg1),
          autofocus: true,
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBrandOrange)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBrandOrange)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: kFg2))),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) LibraryController.inst.renamePlaylist(playlist.id, name);
              Get.back();
            },
            child: const Text('Rename', style: TextStyle(color: kBrandOrange)),
          ),
        ],
      ),
    );
  }

  void _delete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBg1,
        title: const Text('Delete playlist?', style: TextStyle(color: kFg1)),
        content: Text('Delete "${playlist.name}"? Tracks are not deleted.',
            style: const TextStyle(color: kFg2)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: kFg2))),
          TextButton(
            onPressed: () {
              LibraryController.inst.deletePlaylist(playlist.id);
              Get.back();
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(color: kBrandCoral)),
          ),
        ],
      ),
    );
  }
}
