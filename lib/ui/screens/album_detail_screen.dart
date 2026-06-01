import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../../services/audio_handler.dart';
import '../widgets/album_art.dart';
import 'artist_detail_screen.dart';
import 'now_playing_screen.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumName;
  final List<Track> tracks;
  const AlbumDetailScreen({super.key, required this.albumName, required this.tracks});

  @override
  Widget build(BuildContext context) {
    final sorted = [...tracks]..sort((a, b) {
      final cmp = a.trackNo.compareTo(b.trackNo);
      return cmp != 0 ? cmp : a.title.compareTo(b.title);
    });
    final totalMs  = sorted.fold(0, (s, t) => s + t.durationMs);
    final totalMin = totalMs ~/ 60000;
    final totalSec = (totalMs % 60000) ~/ 1000;
    final durationLabel = totalMin >= 60
        ? '${totalMin ~/ 60}h ${totalMin % 60}m'
        : '${totalMin}m ${totalSec.toString().padLeft(2,'0')}s';
    final artist = sorted.first.albumArtist.isNotEmpty
        ? sorted.first.albumArtist
        : sorted.first.artist;
    // Primary artist key (for navigation to ArtistDetailScreen)
    final primaryArtist = artist
        .split(RegExp(r'\s+(feat\.|ft\.|&|,)\s+', caseSensitive: false))
        .first.trim();

    return Scaffold(
      backgroundColor: kBg0,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280, pinned: true, backgroundColor: kBg0,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: kFg1), onPressed: () => Get.back()),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              AlbumArt(artUri: sorted.first.artUri, filePath: sorted.first.filePath,
                  seed: albumName, size: double.infinity, radius: 0),
              Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, kBg0.withAlpha(200), kBg0],
              ))),
            ]),
          ),
        ),

        // Header metadata
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Eyebrow
            const Text('ALBUM COLLECTION',
                style: TextStyle(color: kBrandOrange, fontSize: 8, letterSpacing: 3, fontFamily: 'Barlow')),
            const SizedBox(height: 6),
            // Title — large Syne italic
            Text(albumName, style: const TextStyle(
                color: kFg1, fontSize: 32, fontWeight: FontWeight.w800,
                fontFamily: 'Syne', letterSpacing: -0.5, height: 1.05)),
            const SizedBox(height: 6),
            // Artist — tappable, orange
            GestureDetector(
              onTap: () {
                final lib = LibraryController.inst;
                if (lib.artists.containsKey(primaryArtist)) {
                  Get.to(() => ArtistDetailScreen(artistName: primaryArtist));
                }
              },
              child: Text('by $artist',
                  style: const TextStyle(
                    color: kBrandOrange, fontSize: 14, fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0x55FF5C1A),
                  )),
            ),
            const SizedBox(height: 12),
            // Pill chips
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (sorted.first.year > 0) _chip('${sorted.first.year}'),
              _chip('${sorted.length} TRACKS'),
              _chip(durationLabel),
              if (sorted.first.genre.isNotEmpty) _chip(sorted.first.genre.toUpperCase()),
            ]),
            const SizedBox(height: 20),
            // Action buttons
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Play Album',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandOrange, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  PlayerController.inst.playTrack(sorted.first, queue: sorted);
                  Get.to(() => const NowPlayingScreen());
                },
              )),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.queue_music, size: 16, color: kFg1),
                label: const Text('Queue', style: TextStyle(color: kFg1, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  for (final t in sorted) AuradecAudioHandler.inst.addToQueue(t);
                  Get.snackbar('', '',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: kBg2, colorText: kFg1,
                    margin: const EdgeInsets.fromLTRB(12,0,12,80),
                    duration: const Duration(seconds: 2), borderRadius: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    messageText: Text('Added ${sorted.length} tracks to queue',
                        style: const TextStyle(color: kFg1, fontSize: 13)),
                    titleText: const SizedBox.shrink());
                },
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.shuffle, color: kFg2, size: 18),
                  onPressed: () {
                    final s = [...sorted]..shuffle();
                    PlayerController.inst.playTrack(s.first, queue: s);
                    Get.to(() => const NowPlayingScreen());
                  },
                ),
              ),
            ]),
          ]),
        )),

        // Tracklist header
        const SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text('TRACKLIST',
              style: TextStyle(color: kBrandGold, fontSize: 9, letterSpacing: 2.5, fontFamily: 'Barlow')),
        )),

        // Tracks
        SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) => _TrackRow(track: sorted[i], index: i + 1, queue: sorted),
          childCount: sorted.length,
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: kBg2, borderRadius: BorderRadius.circular(999),
      border: Border.all(color: kBorder)),
    child: Text(text, style: const TextStyle(
        color: kFg2, fontSize: 9, letterSpacing: 0.8, fontFamily: 'Barlow')),
  );
}

class _TrackRow extends StatelessWidget {
  final Track track;
  final int index;
  final List<Track> queue;
  const _TrackRow({required this.track, required this.index, required this.queue});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        PlayerController.inst.playTrack(track, queue: queue);
        Get.to(() => const NowPlayingScreen());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder.withAlpha(60))),
        ),
        child: Row(children: [
          // Track number
          SizedBox(width: 28,
            child: Text('$index',
                style: const TextStyle(color: kFg3, fontSize: 11, fontFamily: 'Barlow'),
                textAlign: TextAlign.right)),
          const SizedBox(width: 14),
          // Title + artist
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.title,
                style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(track.artist,
                style: const TextStyle(color: kFg2, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 10),
          // Codec badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: kBrandOrange.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kBrandOrange.withAlpha(50)),
            ),
            child: Text(track.codec,
                style: const TextStyle(color: kBrandOrange, fontSize: 8, fontFamily: 'Barlow')),
          ),
          const SizedBox(width: 10),
          // Duration
          Text(_fmt(track.durationMs),
              style: const TextStyle(color: kFg2, fontSize: 11, fontFamily: 'Barlow')),
        ]),
      ),
    );
  }

  String _fmt(int ms) {
    final m = ms ~/ 60000; final s = (ms % 60000) ~/ 1000;
    return '$m:${s.toString().padLeft(2,'0')}';
  }
}
