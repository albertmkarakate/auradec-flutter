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

class _ArtistDetailScreenState extends State<ArtistDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _bio;
  bool _bioLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _fetchBio();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

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
      final lib    = LibraryController.inst;
      final tracks = (lib.artists[widget.artistName] ?? <Track>[]).toList();
      final albums = lib.albums.entries
          .where((e) => e.value.any((t) => t.artist.contains(widget.artistName)))
          .toList()
        ..sort((a, b) {
          final ya = a.value.firstOrNull?.year ?? 0;
          final yb = b.value.firstOrNull?.year ?? 0;
          return yb.compareTo(ya);
        });

      return Scaffold(
        backgroundColor: kBg0,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              expandedHeight: 260, pinned: true, backgroundColor: kBg0,
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: kFg1), onPressed: () => Get.back()),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  // Full-width art from first track
                  AlbumArt(
                    artUri: tracks.isNotEmpty ? tracks.first.artUri : null,
                    filePath: tracks.isNotEmpty ? tracks.first.filePath : null,
                    seed: widget.artistName, size: double.infinity, radius: 0,
                  ),
                  // Gradient overlay: top subtle, bottom full black
                  Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(60),
                      Colors.black.withAlpha(140),
                      kBg0,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ))),
                  // Artist name + stats pinned to bottom of hero
                  Positioned(
                    left: 20, right: 20, bottom: 16,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.artistName, style: const TextStyle(
                          color: kFg1, fontSize: 30, fontWeight: FontWeight.w800,
                          fontFamily: 'Syne', letterSpacing: -0.5, shadows: [
                            Shadow(color: Colors.black54, blurRadius: 12),
                          ])),
                      const SizedBox(height: 4),
                      if (tracks.isNotEmpty)
                        Text('${tracks.length} tracks · ${albums.length} albums',
                            style: const TextStyle(color: kFg2, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: kBg1,
                  child: TabBar(
                    controller: _tabs,
                    labelColor: kFg1,
                    unselectedLabelColor: kFg3,
                    indicatorColor: kBrandOrange,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Barlow'),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Discography'),
                      Tab(text: 'Similar'),
                      Tab(text: 'Stats'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(controller: _tabs, children: [
            _overviewTab(tracks, albums),
            _discographyTab(albums, tracks),
            _similarTab(tracks),
            _statsTab(tracks),

          ]),
        ),
      );
    });
  }

  // ── Overview ────────────────────────────────────────────────────

  Widget _overviewTab(List<Track> tracks, List<MapEntry<String, List<Track>>> albums) {
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: [
      // Action buttons
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(children: [
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Play all', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            style: ElevatedButton.styleFrom(
                backgroundColor: kBrandOrange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: tracks.isEmpty ? null : () {
              PlayerController.inst.playTrack(tracks.first, queue: List.from(tracks));
              Get.to(() => const NowPlayingScreen());
            },
          )),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(Icons.shuffle, color: kFg2, size: 18),
              onPressed: tracks.isEmpty ? null : () {
                final s = [...tracks]..shuffle();
                PlayerController.inst.playTrack(s.first, queue: s);
                Get.to(() => const NowPlayingScreen());
              },
            ),
          ),
        ]),
      ),

      // Bio
      if (_bioLoading)
        const Padding(
          padding: EdgeInsets.all(20),
          child: LinearProgressIndicator(color: kBrandOrange, backgroundColor: kBg2),
        )
      else if (_bio != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBg1, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder)),
            child: Text(
              _bio!.length > 500 ? '${_bio!.substring(0, 500)}…' : _bio!,
              style: const TextStyle(color: kFg2, fontSize: 12, height: 1.6)),
          ),
        ),

      // Albums carousel
      if (albums.isNotEmpty) ...[
        _sectionHead('Albums'),
        SizedBox(height: 150, child: ListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: albums.length,
          itemBuilder: (_, i) {
            final name = albums[i].key; final trks = albums[i].value;
            return GestureDetector(
              onTap: () => Get.to(() => AlbumDetailScreen(albumName: name, tracks: trks)),
              child: Container(width: 110, margin: const EdgeInsets.only(right: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: AlbumArt(artUri: trks.first.artUri, filePath: trks.first.filePath,
                        seed: name, size: 110, radius: 10)),
                  const SizedBox(height: 5),
                  Text(name, style: const TextStyle(color: kFg1, fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (trks.first.year > 0)
                    Text('${trks.first.year}', style: const TextStyle(color: kFg3, fontSize: 9)),
                ])),
            );
          },
        )),
      ],

      // Top tracks
      _sectionHead('Top Tracks'),
      ...tracks.take(5).map((t) => TrackTile(
        track: t,
        onTap: () { PlayerController.inst.playTrack(t, queue: List.from(tracks)); Get.to(() => const NowPlayingScreen()); },
      )),
    ]);
  }

  // ── Discography ─────────────────────────────────────────────────

  Widget _discographyTab(List<MapEntry<String, List<Track>>> albums, List<Track> tracks) {
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: [
      if (albums.isNotEmpty) ...[
        _sectionHead('Albums'),
        ...albums.map((e) {
          final name = e.key; final trks = e.value;
          final first = trks.isNotEmpty ? trks.first : null;
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: AlbumArt(artUri: first?.artUri, filePath: first?.filePath,
                  seed: name, size: 52, radius: 8)),
            title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${trks.length} tracks${first != null && first.year > 0 ? ' · ${first.year}' : ''}',
              style: const TextStyle(color: kFg2, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: kFg3),
            onTap: () => Get.to(() => AlbumDetailScreen(albumName: name, tracks: trks)),
          );
        }),
        _sectionHead('All Tracks'),
      ],
      ...tracks.map((t) => TrackTile(
        track: t,
        onTap: () { PlayerController.inst.playTrack(t, queue: List.from(tracks)); Get.to(() => const NowPlayingScreen()); },
      )),
    ]);
  }

  // ── Similar ─────────────────────────────────────────────────────

  Widget _similarTab(List<Track> tracks) {
    final lib = LibraryController.inst;
    final myGenres = tracks.map((t) => t.genre).where((g) => g.isNotEmpty).toSet();
    final similar = lib.artists.entries
        .where((e) => e.key != widget.artistName)
        .where((e) => myGenres.isNotEmpty
            ? e.value.any((t) => myGenres.contains(t.genre))
            : true)
        .toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    if (similar.isEmpty) {
      return const Center(child: Text('No similar artists found in library',
          style: TextStyle(color: kFg3, fontSize: 13)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.82, crossAxisSpacing: 10, mainAxisSpacing: 14),
      itemCount: similar.length.clamp(0, 30),
      itemBuilder: (ctx, i) {
        final name = similar[i].key;
        final trks = similar[i].value;
        final first = trks.isNotEmpty ? trks.first : null;
        return GestureDetector(
          onTap: () => Get.to(() => ArtistDetailScreen(artistName: name)),
          child: Column(children: [
            Expanded(child: ClipOval(child: AlbumArt(
              artUri: first?.artUri, filePath: first?.filePath,
              seed: name, size: double.infinity, radius: 999))),
            const SizedBox(height: 5),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kFg1, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 9)),
          ]),
        );
      },
    );
  }

  // ── Stats ───────────────────────────────────────────────────────

  Widget _statsTab(List<Track> tracks) {
    if (tracks.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: kFg3)));
    }
    final totalMs    = tracks.fold(0, (s, t) => s + t.durationMs);
    final totalPlays = tracks.fold(0, (s, t) => s + t.plays);
    final totalMin   = totalMs ~/ 60000;
    final loved      = tracks.where((t) => t.loved).length;
    final codecs     = <String, int>{};
    for (final t in tracks) codecs[t.codec] = (codecs[t.codec] ?? 0) + 1;

    final statCards = [
      ['TRACKS',       '${tracks.length}',    Icons.music_note],
      ['TOTAL PLAYS',  '$totalPlays',          Icons.play_arrow],
      ['LISTEN TIME',  '${totalMin}m',         Icons.timer_outlined],
      ['LOVED',        '$loved',               Icons.favorite],
    ];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), children: [
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
        children: statCards.map((c) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBg1, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder)),
          child: Row(children: [
            Icon(c[2] as IconData, color: kBrandOrange, size: 18),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(c[0] as String, style: const TextStyle(color: kFg3, fontSize: 8, letterSpacing: 1.5, fontFamily: 'Barlow')),
              Text(c[1] as String, style: const TextStyle(color: kFg1, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            ]),
          ]),
        )).toList(),
      ),
      const SizedBox(height: 20),
      _sectionHead('Formats'),
      const SizedBox(height: 8),
      ...codecs.entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kBrandOrange.withAlpha(20), borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kBrandOrange.withAlpha(50))),
            child: Text(e.key, style: const TextStyle(color: kBrandOrange, fontSize: 10, fontFamily: 'Barlow'))),
          const SizedBox(width: 12),
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: e.value / tracks.length,
              color: kBrandOrange, backgroundColor: kBg2, minHeight: 4))),
          const SizedBox(width: 10),
          Text('${e.value}', style: const TextStyle(color: kFg2, fontSize: 11, fontFamily: 'Barlow')),
        ]),
      )),
    ]);
  }

  Widget _sectionHead(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(label.toUpperCase(),
        style: const TextStyle(color: kBrandGold, fontSize: 9, letterSpacing: 2.5, fontFamily: 'Barlow')),
  );
}
