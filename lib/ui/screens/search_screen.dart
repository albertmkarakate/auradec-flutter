import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';
import 'genre_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';
  final _recents = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: Column(children: [
        _searchBar(),
        Expanded(child: _q.isEmpty ? _idle() : _results()),
      ])),
    );
  }

  Widget _searchBar() {
    return Container(
      color: kBg1, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Search', style: TextStyle(color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
        const SizedBox(height: 10),
        Container(
          height: 46, decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(23), border: Border.all(color: kBorder)),
          child: TextField(
            controller: _ctrl, autofocus: false,
            style: const TextStyle(color: kFg1, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Tracks, artists, albums, genres…',
              hintStyle: const TextStyle(color: kFg3, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: kFg3, size: 20),
              suffixIcon: _q.isNotEmpty ? IconButton(icon: const Icon(Icons.close, color: kFg2, size: 16), onPressed: () { _ctrl.clear(); setState(() => _q = ''); }) : null,
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onChanged: (v) => setState(() => _q = v.trim()),
            onSubmitted: (v) { if (v.trim().isNotEmpty && !_recents.contains(v.trim())) setState(() => _recents.insert(0, v.trim())); },
          ),
        ),
      ]),
    );
  }

  Widget _idle() {
    return Obx(() {
      final artists = LibraryController.inst.artists.keys.take(8).toList();
      return ListView(children: [
        if (_recents.isNotEmpty) ...[
          _sectionHead('Recent searches', trailing: TextButton(onPressed: () => setState(() => _recents.clear()), child: const Text('Clear', style: TextStyle(color: kFg3, fontSize: 11)))),
          Wrap(spacing: 8, runSpacing: 6, children: _recents.map((t) => ActionChip(
            label: Text(t, style: const TextStyle(color: kFg1, fontSize: 12)),
            backgroundColor: kBg2, side: const BorderSide(color: kBorder),
            onPressed: () => setState(() { _ctrl.text = t; _q = t; }),
          )).toList()),
          const SizedBox(height: 8),
        ],
        _sectionHead('Browse by genre'),
        _genreGrid(),
        const SizedBox(height: 16),
        _sectionHead('Top artists'),
        SizedBox(height: 90, child: ListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: artists.length,
          itemBuilder: (_, i) {
            final name = artists[i];
            return GestureDetector(
              onTap: () => Get.to(() => ArtistDetailScreen(artistName: name)),
              child: Container(width: 74, margin: const EdgeInsets.only(right: 12), child: Column(children: [
                AlbumArt(seed: name, size: 64, radius: 32),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(color: kFg1, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ])),
            );
          },
        )),
        const SizedBox(height: 80),
      ]);
    });
  }

  Widget _genreGrid() {
    const genres = [
      ['Afrobeats', Color(0xFFFF5C1A)], ['Amapiano', Color(0xFF29F89E)],
      ['Afro-soul', Color(0xFFF5B32A)], ['Hip-hop', Color(0xFFa78bfa)],
      ['Dancehall', Color(0xFF34d399)], ['Electronic', Color(0xFF60a5fa)],
    ];
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16), crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 3,
      children: genres.map((g) => GestureDetector(
        onTap: () => Get.to(() => GenreDetailScreen(genre: g[0] as String, color: g[1] as Color)),
        child: Container(
          decoration: BoxDecoration(color: kBg1, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: g[1] as Color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(g[0] as String, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      )).toList(),
    );
  }

  Widget _results() {
    return Obx(() {
      final lib      = LibraryController.inst;
      final ql       = _q.toLowerCase();
      final tracks   = lib.tracks.where((t) => '${t.title} ${t.artist} ${t.album} ${t.genre}'.toLowerCase().contains(ql)).toList();
      final artists  = lib.artists.keys.where((a) => a.toLowerCase().contains(ql)).toList();
      final albums   = lib.albums.keys.where((a) => a.toLowerCase().contains(ql)).toList();
      final playlists = lib.playlists.where((p) => p.name.toLowerCase().contains(ql)).toList();

      if (tracks.isEmpty && artists.isEmpty && albums.isEmpty && playlists.isEmpty) {
        return Center(child: Text('No results for "$_q"', style: const TextStyle(color: kFg3, fontSize: 14)));
      }

      return ListView(children: [
        if (playlists.isNotEmpty) ...[
          _sectionHead('Playlists', count: playlists.length),
          ...playlists.map((pl) {
            final trks = lib.playlistTracks(pl);
            return ListTile(
              leading: AlbumArt(
                artUri: trks.isNotEmpty ? trks.first.artUri : null,
                filePath: trks.isNotEmpty ? trks.first.filePath : null,
                seed: pl.name, size: 48, radius: 8,
              ),
              title: Text(pl.name, style: const TextStyle(color: kFg1, fontSize: 14)),
              subtitle: Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: kFg3),
              onTap: () => Get.to(() => PlaylistDetailScreen(playlist: pl)),
            );
          }),
        ],
        if (artists.isNotEmpty) ...[
          _sectionHead('Artists', count: artists.length),
          ...artists.take(3).map((name) => ListTile(
            leading: AlbumArt(seed: name, size: 46, radius: 23),
            title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14)),
            subtitle: Text('${lib.artists[name]!.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
            onTap: () => Get.to(() => ArtistDetailScreen(artistName: name)),
          )),
        ],
        if (albums.isNotEmpty) ...[
          _sectionHead('Albums', count: albums.length),
          ...albums.take(3).map((name) {
            final trks = lib.albums[name]!;
            return ListTile(
              leading: AlbumArt(artUri: trks.first.artUri, filePath: trks.first.filePath, seed: name, size: 48, radius: 8),
              title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14)),
              subtitle: Text(trks.first.artist, style: const TextStyle(color: kFg2, fontSize: 11)),
              onTap: () => Get.to(() => AlbumDetailScreen(albumName: name, tracks: trks)),
            );
          }),
        ],
        if (tracks.isNotEmpty) ...[
          _sectionHead('Tracks', count: tracks.length),
          ...tracks.map((t) => TrackTile(track: t, onTap: () {
            PlayerController.inst.playTrack(t, queue: tracks);
            Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
          })),
        ],
        const SizedBox(height: 80),
      ]);
    });
  }

  Widget _sectionHead(String label, {int? count, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Text(label.toUpperCase(), style: const TextStyle(color: kBrandGold, fontSize: 9, letterSpacing: 2.5, fontFamily: 'Barlow')),
        if (count != null) ...[const SizedBox(width: 6), Text(count.toString(), style: const TextStyle(color: kFg3, fontSize: 9))],
        const Spacer(),
        if (trailing != null) trailing,
      ]),
    );
  }
}
