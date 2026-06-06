import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../../services/audio_handler.dart';
import '../../services/last_fm_service.dart';
import '../../services/musicbrainz_service.dart';
import '../widgets/album_art.dart';
import '../widgets/bulk_edit_sheet.dart';
import 'artist_detail_screen.dart';
import 'now_playing_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumName;
  final List<Track> tracks;
  const AlbumDetailScreen({super.key, required this.albumName, required this.tracks});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _grid = false;
  bool _selectMode = false;
  final _selected = <String>{};

  // Album info
  LastFmAlbumInfo? _lfInfo;
  String? _wikiBlurb;
  String? _mbReleaseId;
  bool _infoLoading = false;
  bool _bioExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    if (_infoLoading) return;
    if (mounted) setState(() => _infoLoading = true);
    final tracks = widget.tracks;
    final artist = tracks.isNotEmpty
        ? (tracks.first.albumArtist.isNotEmpty ? tracks.first.albumArtist : tracks.first.artist)
            .split(RegExp(r'\s+(feat\.|ft\.|&|,)\s+', caseSensitive: false)).first.trim()
        : '';

    // Parallel fetch: Last.fm + MusicBrainz + Wikipedia
    await Future.wait([
      LastFmService.inst.albumInfo(artist, widget.albumName).then((info) {
        if (mounted) setState(() => _lfInfo = info);
      }).catchError((_) {}),
      MusicBrainzService.inst.searchRelease(widget.albumName, artist).then((releases) {
        if (releases.isNotEmpty && mounted) {
          setState(() {
            _mbReleaseId = releases.first.id;
          });
        }
      }).catchError((_) {}),
      _fetchWikiBlurb(widget.albumName, artist),
    ]);

    if (mounted) setState(() => _infoLoading = false);
  }

  Future<void> _fetchWikiBlurb(String album, String artist) async {
    try {
      final query = Uri.encodeComponent('$album $artist album');
      final res = await http.get(
        Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$query'),
        headers: {'User-Agent': 'Auradec/1.0'}).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['type'] != 'disambiguation') {
          final extract = j['extract'] as String?;
          if (extract != null && extract.isNotEmpty && mounted) {
            setState(() => _wikiBlurb = extract);
          }
        }
      }
    } catch (_) {}
  }

  List<Track> get _sorted {
    final lib = LibraryController.inst;
    final live = lib.albums[widget.albumName] ?? widget.tracks;
    final s = [...live]..sort((a, b) {
      final cmp = a.trackNo.compareTo(b.trackNo);
      return cmp != 0 ? cmp : a.title.compareTo(b.title);
    });
    return s;
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  void _exitSelect() => setState(() { _selectMode = false; _selected.clear(); });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // touch reactive maps so edits refresh the view
      LibraryController.inst.tracks.length;
      final sorted = _sorted;
      if (sorted.isEmpty) {
        return const Scaffold(backgroundColor: kBg0, body: Center(
          child: Text('Album is empty', style: TextStyle(color: kFg2))));
      }
      final totalMs  = sorted.fold(0, (s, t) => s + t.durationMs);
      final totalMin = totalMs ~/ 60000;
      final totalSec = (totalMs % 60000) ~/ 1000;
      final durationLabel = totalMin >= 60
          ? '${totalMin ~/ 60}h ${totalMin % 60}m'
          : '${totalMin}m ${totalSec.toString().padLeft(2,'0')}s';
      final artist = sorted.first.albumArtist.isNotEmpty
          ? sorted.first.albumArtist
          : sorted.first.artist;
      final primaryArtist = artist
          .split(RegExp(r'\s+(feat\.|ft\.|&|,)\s+', caseSensitive: false))
          .first.trim();

      return Scaffold(
        backgroundColor: kBg0,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 280, pinned: true, backgroundColor: kBg0,
            leading: IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.arrow_back, color: kFg1),
              onPressed: () => _selectMode ? _exitSelect() : Get.back(),
            ),
            actions: [
              IconButton(
                tooltip: _grid ? 'List' : 'Grid',
                icon: Icon(_grid ? Icons.view_list : Icons.grid_view, color: kFg2),
                onPressed: () => setState(() => _grid = !_grid),
              ),
              IconButton(
                tooltip: 'Select',
                icon: Icon(Icons.checklist,
                    color: _selectMode ? kBrandOrange : kFg2),
                onPressed: () => setState(() {
                  _selectMode = !_selectMode;
                  if (!_selectMode) _selected.clear();
                }),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                AlbumArt(artUri: sorted.first.artUri, filePath: sorted.first.filePath,
                    seed: widget.albumName, size: double.infinity, radius: 0),
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
              const Text('ALBUM COLLECTION',
                  style: TextStyle(color: kBrandOrange, fontSize: 8, letterSpacing: 3, fontFamily: 'Barlow')),
              const SizedBox(height: 6),
              Text(widget.albumName, style: const TextStyle(
                  color: kFg1, fontSize: 32, fontWeight: FontWeight.w800,
                  fontFamily: 'Syne', letterSpacing: -0.5, height: 1.05)),
              const SizedBox(height: 6),
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
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (sorted.first.year > 0) _chip('${sorted.first.year}'),
                _chip('${sorted.length} TRACKS'),
                _chip(durationLabel),
                if (sorted.first.genre.isNotEmpty) _chip(sorted.first.genre.toUpperCase()),
              ]),
              const SizedBox(height: 20),
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
                    _snack('Added ${sorted.length} tracks to queue');
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

          // ── Album info panel ─────────────────────────────────────
          if (_infoLoading)
            const SliverToBoxAdapter(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: LinearProgressIndicator(color: kBrandOrange, backgroundColor: kBg2),
            ))
          else if (_lfInfo != null || _wikiBlurb != null || _mbReleaseId != null)
            SliverToBoxAdapter(child: _infoPanel()),

          // Tracklist header
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              const Text('TRACKLIST',
                  style: TextStyle(color: kBrandGold, fontSize: 9, letterSpacing: 2.5, fontFamily: 'Barlow')),
              const Spacer(),
              if (_selectMode)
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == sorted.length) {
                      _selected.clear();
                    } else {
                      _selected
                        ..clear()
                        ..addAll(sorted.map((t) => t.path));
                    }
                  }),
                  child: Text(_selected.length == sorted.length ? 'Clear' : 'Select all',
                      style: const TextStyle(color: kBrandOrange, fontSize: 11)),
                ),
            ]),
          )),

          // Tracks — list or grid
          if (_grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 0.82,
                  crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _trackCard(sorted[i], sorted),
                  childCount: sorted.length,
                ),
              ),
            )
          else
            SliverList(delegate: SliverChildBuilderDelegate(
              (ctx, i) => _TrackRow(
                track: sorted[i], index: i + 1, queue: sorted,
                selectMode: _selectMode,
                selected: _selected.contains(sorted[i].path),
                onSelect: () => _toggleSelect(sorted[i].path),
              ),
              childCount: sorted.length,
            )),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
        bottomNavigationBar: _selectMode && _selected.isNotEmpty
            ? _selectionBar()
            : null,
      );
    });
  }

  // ── Album info panel ─────────────────────────────────────────────────────

  Widget _infoPanel() {
    final lf      = _lfInfo;
    final tags    = lf?.tags ?? [];
    final bio     = lf?.wiki ?? _wikiBlurb;
    final mbId    = _mbReleaseId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBg1, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Tags row
          if (tags.isNotEmpty) ...[
            Wrap(spacing: 6, runSpacing: 6, children: tags.map((t) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kBrandGold.withAlpha(20), borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kBrandGold.withAlpha(50))),
                child: Text(t, style: const TextStyle(color: kBrandGold, fontSize: 10, fontFamily: 'Barlow')),
              )).toList()),
            const SizedBox(height: 12),
          ],
          // Bio
          if (bio != null) ...[
            Row(children: [
              const Icon(Icons.auto_stories_outlined, color: kFg3, size: 12),
              const SizedBox(width: 6),
              const Text('ABOUT', style: TextStyle(color: kFg3, fontSize: 9, letterSpacing: 2, fontFamily: 'Barlow')),
              const Spacer(),
              if (bio.length > 350)
                GestureDetector(
                  onTap: () => setState(() => _bioExpanded = !_bioExpanded),
                  child: Text(_bioExpanded ? 'Less' : 'More',
                      style: const TextStyle(color: kBrandOrange, fontSize: 11))),
            ]),
            const SizedBox(height: 8),
            Text(bio,
                maxLines: _bioExpanded ? null : 4,
                overflow: _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(color: kFg2, fontSize: 12, height: 1.65)),
            const SizedBox(height: 12),
          ],
          // External links row
          Wrap(spacing: 8, children: [
            if (mbId != null)
              _infoLink('MusicBrainz', kBrandGreen, () => _openUrl(
                'https://musicbrainz.org/release/$mbId')),
            _infoLink('Last.fm', kBrandCoral, () => _openUrl(
                'https://www.last.fm/music/${Uri.encodeComponent(_artistName())}/${Uri.encodeComponent(widget.albumName)}')),
            _infoLink('Wikipedia', const Color(0xFF6E9EBF), () => _openUrl(
                'https://en.wikipedia.org/wiki/${Uri.encodeComponent(widget.albumName)}')),
            // Refresh
            GestureDetector(
              onTap: () { setState(() { _lfInfo = null; _wikiBlurb = null; _mbReleaseId = null; }); _fetchInfo(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Icon(Icons.refresh, color: kFg3, size: 14)),
            ),
          ]),
        ]),
      ),
    );
  }

  String _artistName() {
    final t = widget.tracks.isNotEmpty ? widget.tracks.first : null;
    return (t?.albumArtist.isNotEmpty == true ? t!.albumArtist : t?.artist ?? '')
        .split(RegExp(r'\s+(feat\.|ft\.|&|,)\s+', caseSensitive: false)).first.trim();
  }

  Widget _infoLink(String label, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
    ),
  );

  void _openUrl(String url) {
    // url_launcher not in pubspec — show snack with URL for now
    Get.snackbar('', '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: kBg2, colorText: kFg1, duration: const Duration(seconds: 3),
      messageText: Text(url, style: const TextStyle(color: kFg2, fontSize: 11)),
      titleText: const SizedBox.shrink());
  }

  Widget _selectionBar() => Container(
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
    decoration: const BoxDecoration(
      color: kBg1, border: Border(top: BorderSide(color: kBorder))),
    child: Row(children: [
      Text('${_selected.length} selected',
          style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600)),
      const Spacer(),
      ElevatedButton.icon(
        icon: const Icon(Icons.edit, size: 16),
        label: const Text('Edit tags'),
        style: ElevatedButton.styleFrom(
            backgroundColor: kBrandOrange, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: _openBulkEdit,
      ),
    ]),
  );

  Widget _trackCard(Track t, List<Track> queue) {
    final selected = _selected.contains(t.path);
    return GestureDetector(
      onTap: () {
        if (_selectMode) { _toggleSelect(t.path); return; }
        PlayerController.inst.playTrack(t, queue: queue);
        Get.to(() => const NowPlayingScreen());
      },
      onLongPress: () => setState(() { _selectMode = true; _selected.add(t.path); }),
      child: Container(
        decoration: BoxDecoration(
          color: kBg1, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? kBrandOrange : kBorder, width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AlbumArt(artUri: t.artUri, filePath: t.filePath, seed: t.title, size: double.infinity, radius: 0),
            ),
            if (_selectMode)
              Positioned(top: 6, left: 6, child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? kBrandOrange : Colors.white70, size: 22)),
          ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: const TextStyle(color: kFg1, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(t.artist, style: const TextStyle(color: kFg2, fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _openBulkEdit() async {
    final paths = _selected.toList();
    final sel = _sorted.where((t) => paths.contains(t.path)).toList();
    if (sel.isEmpty) return;

    final n = await showBulkEditSheet(context, sel);
    if (n < 0) { _snack('Storage permission needed to write tags'); return; }
    _snack(n > 0 ? 'Updated $n track${n == 1 ? '' : 's'}' : 'No changes written');
    _exitSelect();
  }

  void _snack(String msg) {
    Get.snackbar('', '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: kBg2, colorText: kFg1,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      duration: const Duration(seconds: 2), borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      messageText: Text(msg, style: const TextStyle(color: kFg1, fontSize: 13)),
      titleText: const SizedBox.shrink());
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
  final bool selectMode;
  final bool selected;
  final VoidCallback onSelect;
  const _TrackRow({
    required this.track, required this.index, required this.queue,
    required this.selectMode, required this.selected, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (selectMode) { onSelect(); return; }
        PlayerController.inst.playTrack(track, queue: queue);
        Get.to(() => const NowPlayingScreen());
      },
      onLongPress: selectMode ? null : onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kBrandOrange.withAlpha(18) : null,
          border: Border(bottom: BorderSide(color: kBorder.withAlpha(60))),
        ),
        child: Row(children: [
          if (selectMode)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? kBrandOrange : kFg3, size: 20),
            )
          else ...[
            SizedBox(width: 28,
              child: Text('$index',
                  style: const TextStyle(color: kFg3, fontSize: 11, fontFamily: 'Barlow'),
                  textAlign: TextAlign.right)),
            const SizedBox(width: 14),
          ],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.title,
                style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(track.artist,
                style: const TextStyle(color: kFg2, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
            final stars = (track.rating / 20).round().clamp(0, 5);
            return Icon(i < stars ? Icons.star : Icons.star_border,
                color: i < stars ? const Color(0xFFFBBF24) : kFg3, size: 9);
          })),
          const SizedBox(width: 8),
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
