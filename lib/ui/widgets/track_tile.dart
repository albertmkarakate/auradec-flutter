import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../widgets/album_art.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final bool isPlaying;
  final bool showNumber;
  final Widget? trailingAction;

  const TrackTile({
    super.key,
    required this.track,
    this.onTap,
    this.isPlaying = false,
    this.showNumber = false,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder.withAlpha(80))),
          color: isPlaying ? kBrandOrange.withAlpha(20) : Colors.transparent,
        ),
        child: Row(children: [
          if (isPlaying)
            Container(width: 3, height: 46, color: kBrandOrange, margin: const EdgeInsets.only(right: 8)),
          if (showNumber && !isPlaying)
            SizedBox(width: 24, child: Text(
              track.trackNo > 0 ? '${track.trackNo}' : '·',
              style: const TextStyle(color: kFg3, fontSize: 11),
              textAlign: TextAlign.center,
            ))
          else if (!isPlaying) ...[
            // Album art
            AlbumArt(artUri: track.artUri, seed: track.title, size: 46, radius: 10),
            const SizedBox(width: 2),
          ] else ...[
            AlbumArt(artUri: track.artUri, seed: track.title, size: 46, radius: 10),
            const SizedBox(width: 2),
          ],
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              track.title,
              style: TextStyle(
                color: isPlaying ? kBrandOrange : kFg1,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(track.artist, style: const TextStyle(color: kFg2, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              _codecBadge(),
              const SizedBox(width: 6),
              if (track.bitrate > 0)
                Text('${track.bitrate}k', style: const TextStyle(color: kFg3, fontSize: 9)),
              const SizedBox(width: 4),
              Text(_fmt(track.durationMs), style: const TextStyle(color: kFg3, fontSize: 9)),
            ]),
          ])),
          if (trailingAction != null)
            trailingAction!
          else
            IconButton(
              icon: const Icon(Icons.more_vert, color: kFg3, size: 18),
              onPressed: () => _showMenu(context),
            ),
        ]),
      ),
    );
  }

  Widget _codecBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: kBrandOrange.withAlpha(25),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: kBrandOrange.withAlpha(50)),
    ),
    child: Text(track.codec, style: const TextStyle(color: kBrandOrange, fontSize: 8)),
  );

  String _fmt(int ms) {
    final m = ms ~/ 60000; final s = (ms % 60000) ~/ 1000;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TrackMenu(track: track),
    );
  }
}

class _TrackMenu extends StatelessWidget {
  final Track track;
  const _TrackMenu({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Obx(() {
        final lib      = LibraryController.inst;
        final loved    = lib.lovedPaths.contains(track.path);
        final playlists = lib.playlists;

        return Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              AlbumArt(artUri: track.artUri, seed: track.title, size: 52, radius: 10),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(track.title, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${track.artist} · ${track.codec} · ${track.bitrate}k',
                    style: const TextStyle(color: kFg3, fontSize: 11)),
              ])),
            ]),
          ),
          const Divider(color: kBorder, height: 1),
          _item(
            loved ? Icons.favorite : Icons.favorite_border,
            loved ? 'Remove from loved' : 'Add to loved',
            () { lib.toggleLoved(track.path); Get.back(); },
            color: loved ? kBrandCoral : null,
          ),
          if (playlists.isNotEmpty)
            _item(Icons.playlist_add, 'Add to playlist', () {
              Get.back();
              _showPlaylistPicker(context, lib);
            }),
          _item(Icons.queue_music, 'Add to queue', () => Get.back()),
          _item(Icons.info_outline, 'Track info', () {
            Get.back();
            _showInfo(context);
          }),
          _item(Icons.block, 'Exclude from library', () {
            lib.excludeTrack(track.path); Get.back();
          }, color: kBrandCoral),
        ]);
      }),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap, {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? kFg2, size: 20),
        title: Text(label, style: TextStyle(color: color ?? kFg1, fontSize: 14)),
        onTap: onTap, dense: true,
      );

  void _showPlaylistPicker(BuildContext context, LibraryController lib) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Obx(() => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Add to playlist', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        ...lib.playlists.map((pl) => ListTile(
          leading: const Icon(Icons.playlist_play, color: kBrandOrange),
          title: Text(pl.name, style: const TextStyle(color: kFg1)),
          subtitle: Text('${lib.playlistTracks(pl).length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
          onTap: () { lib.addToPlaylist(pl.id, track.path); Get.back(); },
        )),
        const SizedBox(height: 16),
      ])),
    );
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.title, style: const TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            ['Artist', track.artist],
            ['Album', track.album],
            ['Year', track.year > 0 ? '${track.year}' : '—'],
            ['Genre', track.genre.isNotEmpty ? track.genre : '—'],
            ['Codec', track.codec],
            ['Bitrate', '${track.bitrate} kbps'],
            ['Sample rate', '${track.sampleRate} Hz'],
            ['Duration', _fmtMs(track.durationMs)],
            ['File', track.filename],
          ].map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 90, child: Text(row[0], style: const TextStyle(color: kFg3, fontSize: 11))),
              Expanded(child: Text(row[1], style: const TextStyle(color: kFg1, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          )),
        ]),
      ),
    );
  }

  String _fmtMs(int ms) {
    final m = ms ~/ 60000; final s = (ms % 60000) ~/ 1000;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
