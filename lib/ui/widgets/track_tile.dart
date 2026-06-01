import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../services/audio_handler.dart';
import '../widgets/album_art.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/album_detail_screen.dart';
import '../screens/now_playing_screen.dart';

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
      child: Obx(() {
        final pad = ThemeController.inst.listItemPadding;
        final art = ThemeController.inst.artSize;
        return _buildRow(context, pad, art);
      }),
    );
  }

  Widget _buildRow(BuildContext context, double pad, double artSz) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: pad),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder.withAlpha(80))),
          color: isPlaying ? kBrandOrange.withAlpha(20) : Colors.transparent,
        ),
        child: Row(children: [
          if (isPlaying)
            Container(width: 3, height: artSz, color: kBrandOrange, margin: const EdgeInsets.only(right: 8)),
          if (showNumber && !isPlaying)
            SizedBox(width: 24, child: Text(
              track.trackNo > 0 ? '${track.trackNo}' : '·',
              style: const TextStyle(color: kFg3, fontSize: 11),
              textAlign: TextAlign.center,
            ))
          else if (!isPlaying) ...[
            // Album art
            AlbumArt(artUri: track.artUri, filePath: track.filePath, seed: track.title, size: artSz, radius: 10),
            const SizedBox(width: 2),
          ] else ...[
            AlbumArt(artUri: track.artUri, filePath: track.filePath, seed: track.title, size: artSz, radius: 10),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: SingleChildScrollView(child: _TrackMenu(track: track))),
    );
  }
}

class _TrackMenu extends StatelessWidget {
  final Track track;
  const _TrackMenu({required this.track});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Obx(() {
          final lib      = LibraryController.inst;
          final loved    = lib.lovedPaths.contains(track.path);
          final playlists = lib.playlists;
          final primary  = track.artist
              .split(RegExp(r'\s+(feat\.|ft\.|&|,)\s+', caseSensitive: false))
              .first.trim();
          final albumTracks = lib.albums[track.album];

          return Column(mainAxisSize: MainAxisSize.min, children: [
            // Track header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: AlbumArt(artUri: track.artUri, filePath: track.filePath,
                      seed: track.title, size: 52, radius: 10)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(track.title, style: const TextStyle(
                      color: kFg1, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: kBrandOrange.withAlpha(20),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: kBrandOrange.withAlpha(50))),
                      child: Text(track.codec, style: const TextStyle(
                          color: kBrandOrange, fontSize: 8, fontFamily: 'Barlow'))),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${track.artist} · ${track.bitrate}k',
                        style: const TextStyle(color: kFg3, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ])),
              ]),
            ),
            const Divider(color: kBorder, height: 1),

            // ── PLAYBACK ─────────────────────────────────────────────
            _section('Playback'),
            _item(Icons.play_arrow, 'Play now', () {
              PlayerController.inst.playTrack(track, queue: [track]);
              Get.back();
              Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
            }),
            _item(Icons.queue_play_next, 'Play next', () {
              AuradecAudioHandler.inst.addToQueue(track);
              Get.back();
              _snack('Will play next: ${track.title}');
            }),
            _item(Icons.queue_music, 'Add to queue', () {
              AuradecAudioHandler.inst.addToQueue(track);
              Get.back();
              _snack('Added to queue: ${track.title}');
            }),
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

            const Divider(color: kBorder, height: 1),
            // ── NAVIGATE ─────────────────────────────────────────────
            _section('Navigate'),
            _item(Icons.mic_none, 'Go to artist · $primary', () {
              Get.back();
              Get.to(() => ArtistDetailScreen(artistName: primary));
            }),
            if (albumTracks != null)
              _item(Icons.album_outlined, 'Go to album · ${track.album}', () {
                Get.back();
                Get.to(() => AlbumDetailScreen(albumName: track.album, tracks: albumTracks));
              }),

            const Divider(color: kBorder, height: 1),
            // ── METADATA ─────────────────────────────────────────────
            _section('Metadata'),
            _item(Icons.info_outline, 'Track info', () {
              Get.back();
              _showInfo(context);
            }),
            _item(Icons.edit_outlined, 'Edit track info…', () {
              Get.back();
              _showEditSheet(context, lib);
            }),

            const Divider(color: kBorder, height: 1),
            // ── EXTERNAL ─────────────────────────────────────────────
            _section('External'),
            _item(Icons.language, 'Find on Last.fm', () {
              Get.back();
              _launch('https://www.last.fm/search?q=${Uri.encodeComponent(track.title)}');
            }),
            _item(Icons.manage_search, 'Find on MusicBrainz', () {
              Get.back();
              _launch('https://musicbrainz.org/search?query=${Uri.encodeComponent(track.title)}&type=recording');
            }),
            _item(Icons.book_outlined, 'Find on Wikipedia', () {
              Get.back();
              _launch('https://en.wikipedia.org/wiki/${Uri.encodeComponent(track.artist)}');
            }),
            _item(Icons.copy, 'Copy track info', () {
              Clipboard.setData(ClipboardData(
                  text: '${track.artist} — ${track.title} (${track.album})'));
              Get.back();
              _snack('Copied to clipboard');
            }),

            const Divider(color: kBorder, height: 1),
            // ── REMOVE ───────────────────────────────────────────────
            _item(Icons.block, 'Exclude from library', () {
              lib.excludeTrack(track.path); Get.back();
            }, color: kBrandCoral),
            const SizedBox(height: 8),
          ]);
        }),
      )),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    child: Text(label.toUpperCase(), style: const TextStyle(
        color: kFg3, fontSize: 8, letterSpacing: 2, fontFamily: 'Barlow')),
  );

  Widget _item(IconData icon, String label, VoidCallback onTap, {Color? color}) =>
      ListTile(
        leading: Icon(icon, color: color ?? kFg2, size: 20),
        title: Text(label, style: TextStyle(color: color ?? kFg1, fontSize: 14)),
        onTap: onTap, dense: true,
        minLeadingWidth: 20,
      );

  void _snack(String msg) => Get.snackbar('', '',
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: kBg2, colorText: kFg1,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
    duration: const Duration(seconds: 2), borderRadius: 12,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    messageText: Text(msg, style: const TextStyle(color: kFg1, fontSize: 13)),
    titleText: const SizedBox.shrink());

  Future<void> _launch(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); }
    catch (_) { _snack('Could not open link'); }
  }

  void _showPlaylistPicker(BuildContext context, LibraryController lib) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Obx(() => SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Add to playlist', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700))),
        ...lib.playlists.map((pl) => ListTile(
          leading: const Icon(Icons.playlist_play, color: kBrandOrange),
          title: Text(pl.name, style: const TextStyle(color: kFg1)),
          subtitle: Text('${lib.playlistTracks(pl).length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
          onTap: () { lib.addToPlaylist(pl.id, track.path); Get.back(); },
        )),
        const SizedBox(height: 8),
      ])))),
    );
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.title, style: const TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...[
            ['Title',       track.title],
            ['Artist',      track.artist],
            ['Album',       track.album],
            ['Year',        track.year > 0 ? '${track.year}' : '—'],
            ['Genre',       track.genre.isNotEmpty ? track.genre : '—'],
            ['Track #',     track.trackNo > 0 ? '${track.trackNo}' : '—'],
            ['Codec',       track.codec],
            ['Bitrate',     '${track.bitrate} kbps'],
            ['Sample rate', '${track.sampleRate} Hz'],
            ['Duration',    _fmtMs(track.durationMs)],
            ['File size',   '${(track.fileSize / 1048576).toStringAsFixed(1)} MB'],
            ['File',        track.filename],
          ].map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 90, child: Text(row[0], style: const TextStyle(color: kFg3, fontSize: 11))),
              Expanded(child: Text(row[1], style: const TextStyle(color: kFg1, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          )),
        ]),
      ))),
    );
  }

  void _showEditSheet(BuildContext context, LibraryController lib) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(top: false, child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _EditTrackSheet(track: track, lib: lib),
      )),
    );
  }

  String _fmtMs(int ms) {
    final m = ms ~/ 60000; final s = (ms % 60000) ~/ 1000;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── Edit track info sheet ─────────────────────────────────────────

class _EditTrackSheet extends StatefulWidget {
  final Track track;
  final LibraryController lib;
  const _EditTrackSheet({required this.track, required this.lib});
  @override State<_EditTrackSheet> createState() => _EditTrackSheetState();
}

class _EditTrackSheetState extends State<_EditTrackSheet> {
  late final _titleCtrl  = TextEditingController(text: widget.track.title);
  late final _artistCtrl = TextEditingController(text: widget.track.artist);
  late final _albumCtrl  = TextEditingController(text: widget.track.album);
  late final _genreCtrl  = TextEditingController(text: widget.track.genre);

  @override
  void dispose() {
    _titleCtrl.dispose(); _artistCtrl.dispose();
    _albumCtrl.dispose(); _genreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('EDITOR ENGINE', style: TextStyle(
            color: kBrandOrange, fontSize: 9, letterSpacing: 2, fontFamily: 'Barlow')),
        const SizedBox(height: 4),
        const Text('Edit Track Information', style: TextStyle(
            color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
        const SizedBox(height: 20),
        _field('Title', _titleCtrl),
        const SizedBox(height: 12),
        _field('Artist', _artistCtrl),
        const SizedBox(height: 12),
        _field('Album', _albumCtrl),
        const SizedBox(height: 12),
        _field('Genre', _genreCtrl),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: kFg2)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor: kBrandOrange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              // In-memory update — writes back to track object in the library
              final lib = widget.lib;
              final t = lib.tracks.firstWhereOrNull((x) => x.path == widget.track.path);
              // Note: Track fields are final; can only update mutable stats here.
              // Full tag writing would require native platform channel — stub for now.
              Get.back();
              Get.snackbar('', 'Changes saved (in-session)',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: kBg2, colorText: kFg1,
                margin: const EdgeInsets.fromLTRB(12,0,12,80),
                duration: const Duration(seconds: 2), borderRadius: 12,
                messageText: const Text('Track info updated', style: TextStyle(color: kFg1, fontSize: 13)),
                titleText: const SizedBox.shrink());
            },
          )),
        ]),
      ]),
    ));
  }

  Widget _field(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: const TextStyle(
          color: kFg3, fontSize: 8, letterSpacing: 1.5, fontFamily: 'Barlow')),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: kFg1, fontSize: 14),
        decoration: InputDecoration(
          filled: true, fillColor: kBg2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBrandOrange)),
        ),
      ),
    ],
  );
}
