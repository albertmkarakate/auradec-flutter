import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../widgets/auradec_mark.dart';
import 'analytics_screen.dart';
import '../../controllers/player_controller.dart';
import '../widgets/track_tile.dart';
import '../widgets/album_art.dart';
import 'folder_picker_screen.dart';
import 'now_playing_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';
import '../../services/audio_handler.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _SortMode { title, artist, album, dateAdded, duration }

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  String _query = '';
  String _activeTab = 'tracks';
  _SortMode _sortMode = _SortMode.title;
  bool _sortAsc = true;
  // Per-tab grid/list state — tracks & loved always list
  final _gridLayout = <String, bool>{
    'tracks': true, 'albums': true, 'artists': true, 'playlists': true, 'loved': false,
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) return;
      final labels = ['tracks', 'albums', 'artists', 'playlists', 'loved'];
      setState(() {
        _activeTab = labels[_tabs.index];
        _sortMode  = _SortMode.title;
      });
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildTabBar(),
          _actionToolbar(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: kBg1,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        Row(children: [
          _logomark(),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(text: const TextSpan(children: [
                TextSpan(text: 'AURA', style: TextStyle(color: kFg1, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
                TextSpan(text: 'DEC', style: TextStyle(color: kBrandOrange, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
              ])),
              const Text('Sound for every culture', style: TextStyle(color: kBrandGold, fontSize: 8, letterSpacing: 3, fontFamily: 'Barlow')),
            ],
          )),
          _toolbarActions(),
        ]),
        const SizedBox(height: 10),
        _searchBar(),
        const SizedBox(height: 8),
        _statsBar(),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _statsBar() {
    return Obx(() {
      final lib = LibraryController.inst;
      if (lib.tracks.isEmpty) return const SizedBox.shrink();
      final totalMs  = lib.tracks.fold(0, (s, t) => s + t.durationMs);
      final totalH   = totalMs ~/ 3600000;
      final totalM   = (totalMs % 3600000) ~/ 60000;
      final durLabel = totalH > 0 ? '${totalH}h ${totalM}m' : '${totalM}m';
      final stats = [
        ['TRACKS',   '${lib.tracks.length}'],
        ['ARTISTS',  '${lib.artists.length}'],
        ['ALBUMS',   '${lib.albums.length}'],
        ['DURATION', durLabel],
      ];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(stats.length, (i) => Container(
            margin: EdgeInsets.only(right: i < stats.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: kBg1,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(stats[i][0], style: const TextStyle(
                  color: kFg3, fontSize: 8, letterSpacing: 1.5, fontFamily: 'Barlow')),
              const SizedBox(width: 6),
              Text(stats[i][1], style: const TextStyle(
                  color: kFg1, fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            ]),
          )),
        ),
      );
    });
  }


  Widget _logomark() => const AuradecMark(size: 32);

  Widget _toolbarActions() {
    final hasToggle = _activeTab != 'loved';
    final grid = _gridLayout[_activeTab] ?? false;
    return Row(children: [
      if (hasToggle)
        IconButton(
          icon: Icon(grid ? Icons.view_list : Icons.grid_view,
              color: grid ? kBrandOrange : kFg2, size: 22),
          tooltip: 'Toggle layout',
          onPressed: () => setState(() => _gridLayout[_activeTab] = !grid),
        ),
      Obx(() {
        final scanning = LibraryController.inst.isScanning.value;
        return IconButton(
          icon: scanning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kBrandOrange, strokeWidth: 2))
              : const Icon(Icons.refresh, color: kFg2, size: 22),
          onPressed: scanning ? null : () => LibraryController.inst.scanLibrary(),
          tooltip: 'Scan device',
        );
      }),
      IconButton(
        icon: const Icon(Icons.more_vert, color: kFg2, size: 22),
        onPressed: () => _showLibraryMenu(),
      ),
    ]);
  }

  void _showSortSheet() {
    // Tab-specific sort options
    final isAlbums  = _activeTab == 'albums';
    final isArtists = _activeTab == 'artists';

    final Map<_SortMode, String> labels = isAlbums
        ? {_SortMode.title: 'Name', _SortMode.duration: 'Track count', _SortMode.dateAdded: 'Year'}
        : isArtists
        ? {_SortMode.title: 'Name', _SortMode.duration: 'Track count'}
        : {_SortMode.title: 'Title', _SortMode.artist: 'Artist', _SortMode.album: 'Album',
           _SortMode.dateAdded: 'Year / Date', _SortMode.duration: 'Duration'};

    final Map<_SortMode, IconData> icons = {
      _SortMode.title:     Icons.sort_by_alpha,
      _SortMode.artist:    Icons.mic,
      _SortMode.album:     Icons.album,
      _SortMode.dateAdded: Icons.calendar_today_outlined,
      _SortMode.duration:  isAlbums || isArtists ? Icons.format_list_numbered : Icons.timer_outlined,
    };

    showModalBottomSheet(
      context: context, backgroundColor: kBg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => SafeArea(
        child: SingleChildScrollView(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text('Sort ${isAlbums ? "albums" : isArtists ? "artists" : "tracks"}',
                style: const TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () { setState(() => _sortAsc = !_sortAsc); setS(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, color: kBrandOrange, size: 14),
                  const SizedBox(width: 4),
                  Text(_sortAsc ? 'Ascending' : 'Descending',
                      style: const TextStyle(color: kFg1, fontSize: 12)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ...labels.entries.map((e) {
            final m      = e.key;
            final label  = e.value;
            final active = _sortMode == m;
            return ListTile(
              leading: Icon(icons[m], color: active ? kBrandOrange : kFg2, size: 20),
              title: Text(label, style: TextStyle(color: active ? kBrandOrange : kFg1,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
              trailing: active ? const Icon(Icons.check, color: kBrandOrange, size: 18) : null,
              onTap: () { setState(() => _sortMode = m); setS(() {}); },
              dense: true,
            );
          }),
        ]),
      )))),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: kBg2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
      ),
      child: TextField(
        controller: _search,
        style: const TextStyle(color: kFg1, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search tracks, artists…',
          hintStyle: TextStyle(color: kFg3, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: kFg3, size: 18),
          suffixIcon: _query.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, color: kFg2, size: 16), onPressed: () { _search.clear(); setState(() => _query = ''); })
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: kBg1,
      child: TabBar(
        controller: _tabs,
        labelColor: Colors.white,
        unselectedLabelColor: kFg2,
        indicatorColor: kBrandOrange,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Tracks'), Tab(text: 'Albums'),
          Tab(text: 'Artists'), Tab(text: 'Playlists'),
          Tab(icon: Icon(Icons.favorite, size: 14)),
        ],
      ),
    );
  }

  Widget _actionToolbar() {
    final grid = _gridLayout[_activeTab] ?? false;
    const sortLabels = {
      _SortMode.title:    'Title',
      _SortMode.artist:   'Artist',
      _SortMode.album:    'Album',
      _SortMode.dateAdded:'Date',
      _SortMode.duration: 'Duration',
    };
    final sortLabel = sortLabels[_sortMode] ?? 'Title';
    final sortDir = _sortAsc ? '↑' : '↓';
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: kBg1,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), children: [
        _tbBtn(Icons.play_arrow, 'Play all', onTap: () {
          final lib = LibraryController.inst;
          if (lib.tracks.isEmpty) return;
          PlayerController.inst.playTrack(lib.tracks.first, queue: lib.tracks.toList());
          Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
        }),
        _tbBtn(Icons.shuffle, 'Shuffle', onTap: () {
          final lib = LibraryController.inst;
          if (lib.tracks.isEmpty) return;
          final q = lib.tracks.toList()..shuffle();
          PlayerController.inst.playTrack(q.first, queue: q);
          Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
        }),
        _tbDivider(),
        _tbBtn(Icons.sort, '$sortLabel $sortDir', active: true, onTap: _showSortSheet),
        _tbBtn(grid ? Icons.view_list : Icons.grid_view, grid ? 'List' : 'Grid',
            onTap: () => setState(() => _gridLayout[_activeTab] = !grid)),
        _tbBtn(Icons.add, 'New', onTap: _showLibraryMenu),
        Obx(() {
          final scanning = LibraryController.inst.isScanning.value;
          return _tbBtn(scanning ? Icons.hourglass_bottom : Icons.manage_search,
              scanning ? 'Scanning…' : 'Scan device',
              accent: const Color(0xFF29F89E),
              onTap: scanning ? null : () => LibraryController.inst.scanLibrary());
        }),
        _tbBtn(Icons.folder_outlined, 'Folders', accent: kBrandGold,
            onTap: () => Get.to(() => const FolderPickerScreen())),
      ]),
    );
  }

  Widget _tbBtn(IconData icon, String label,
      {VoidCallback? onTap, bool active = false, Color? accent}) {
    final col = active ? kBrandOrange : (accent ?? kFg2);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kBrandOrange.withAlpha(20) : kBg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? kBrandOrange.withAlpha(90) : kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: col, size: 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: col, fontSize: 10, fontFamily: 'Barlow',
              fontWeight: active ? FontWeight.w600 : FontWeight.w400, letterSpacing: 0.3)),
        ]),
      ),
    );
  }

  Widget _tbDivider() => Container(
    width: 1, height: 20, color: kBorder,
    margin: const EdgeInsets.only(right: 6),
  );

  Widget _buildBody() {
    return TabBarView(controller: _tabs, children: [
      _trackList(),
      _albumGrid(),
      _artistList(),
      _playlists(),
      _lovedList(),
    ]);
  }

  Widget _trackList() {
    return Obx(() {
      final lib = LibraryController.inst;
      final all = lib.tracks;

      if (lib.isScanning.value && all.isEmpty) {
        return _scanningState();
      }
      if (all.isEmpty) {
        return _emptyState();
      }

      var filtered = _query.isEmpty ? all.toList()
          : all.where((t) => '${t.title} ${t.artist} ${t.album} ${t.genre}'
              .toLowerCase().contains(_query.toLowerCase())).toList();

      // Apply sort
      int cmp(a, b) {
        int r;
        switch (_sortMode) {
          case _SortMode.artist:   r = a.artist.compareTo(b.artist); break;
          case _SortMode.album:    r = a.album.compareTo(b.album); break;
          case _SortMode.dateAdded: r = a.lastPlayed.compareTo(b.lastPlayed); break;
          case _SortMode.duration: r = a.durationMs.compareTo(b.durationMs); break;
          default:                 r = a.title.compareTo(b.title);
        }
        return _sortAsc ? r : -r;
      }
      filtered.sort(cmp);

      if (_gridLayout['tracks'] ?? true) {
        // Full TrackTile with album art (default)
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: filtered.length,
          itemBuilder: (ctx, i) => TrackTile(
            track: filtered[i],
            onTap: () {
              PlayerController.inst.playTrack(filtered[i], queue: filtered);
              Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
            },
          ),
        );
      }

      // Compact list: smaller art, condensed padding
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final t = filtered[i];
          return InkWell(
            onTap: () {
              PlayerController.inst.playTrack(t, queue: filtered);
              Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(children: [
                AlbumArt(artUri: t.artUri, filePath: t.filePath, seed: t.title, size: 36, radius: 7),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${t.artist} · ${t.album}', style: const TextStyle(color: kFg2, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Text(_fmtMs(t.durationMs), style: const TextStyle(color: kFg3, fontSize: 10)),
              ]),
            ),
          );
        },
      );
    });
  }

  String _fmtMs(int ms) {
    final m = ms ~/ 60000; final s = (ms % 60000) ~/ 1000;
    return '$m:${s.toString().padLeft(2,'0')}';
  }

  Widget _albumGrid() {
    return Obx(() {
      final albums = LibraryController.inst.albums;
      if (albums.isEmpty) return const SizedBox();
      var keys = albums.keys.toList();
      // Sort albums
      switch (_sortMode) {
        case _SortMode.duration: // reuse as "track count"
          keys.sort((a, b) {
            final r = albums[a]!.length.compareTo(albums[b]!.length);
            return _sortAsc ? r : -r;
          });
          break;
        case _SortMode.dateAdded: // reuse as year
          keys.sort((a, b) {
            final ya = albums[a]!.isNotEmpty ? albums[a]!.first.year : 0;
            final yb = albums[b]!.isNotEmpty ? albums[b]!.first.year : 0;
            return _sortAsc ? ya.compareTo(yb) : yb.compareTo(ya);
          });
          break;
        default:
          keys.sort((a, b) => _sortAsc ? a.compareTo(b) : b.compareTo(a));
      }

      if (!(_gridLayout['albums'] ?? true)) {
        // List view
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: keys.length,
          itemBuilder: (ctx, i) {
            final name = keys[i];
            final trks = albums[name]!;
            final first = trks.isNotEmpty ? trks.first : null;
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AlbumArt(artUri: first?.artUri, filePath: first?.filePath, seed: name, size: 52, radius: 8),
              ),
              title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${first?.artist ?? ''} · ${trks.length} tracks${first?.year != null && first!.year > 0 ? ' · ${first.year}' : ''}',
                style: const TextStyle(color: kFg2, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right, color: kFg3),
              onTap: () => Get.to(() => AlbumDetailScreen(albumName: name, tracks: trks)),
              onLongPress: () => _showAlbumMenu(name, trks),
            );
          },
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.8,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: keys.length,
        itemBuilder: (ctx, i) {
          final name = keys[i];
          final trks = albums[name]!;
          return _albumCard(name, trks);
        },
      );
    });
  }

  Widget _albumCard(String name, List<Track> tList) {
    final first  = tList.isNotEmpty ? tList.first : null;
    return GestureDetector(
      onTap: () => Get.to(() => AlbumDetailScreen(albumName: name, tracks: tList)),
      onLongPress: () => _showAlbumMenu(name, tList),
      child: Container(
        decoration: BoxDecoration(
          color: kBg1, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: AlbumArt(artUri: first?.artUri, filePath: first?.filePath, seed: name, size: double.infinity, radius: 0),
          )),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${tList.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _artistList() {
    return Obx(() {
      final artists = LibraryController.inst.artists;
      var keys = artists.keys.toList();
      if (keys.isEmpty) return const SizedBox();
      if (_sortMode == _SortMode.duration) {
        keys.sort((a, b) {
          final r = (artists[a]?.length ?? 0).compareTo(artists[b]?.length ?? 0);
          return _sortAsc ? r : -r;
        });
      } else {
        keys.sort((a, b) => _sortAsc ? a.compareTo(b) : b.compareTo(a));
      }

      if (_gridLayout['artists'] ?? true) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.82,
            crossAxisSpacing: 10, mainAxisSpacing: 14,
          ),
          itemCount: keys.length,
          itemBuilder: (ctx, i) {
            final name = keys[i];
            final trks = artists[name]!;
            final first = trks.isNotEmpty ? trks.first : null;
            return GestureDetector(
              onTap: () => Get.to(() => ArtistDetailScreen(artistName: name)),
              onLongPress: () => _showArtistMenu(name),
              child: Column(children: [
                Expanded(child: ClipOval(child: AlbumArt(
                  artUri: first?.artUri, filePath: first?.filePath,
                  seed: name, size: double.infinity, radius: 999,
                ))),
                const SizedBox(height: 5),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kFg1, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('${trks.length} tracks',
                  style: const TextStyle(color: kFg2, fontSize: 9)),
              ]),
            );
          },
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: keys.length,
        itemBuilder: (ctx, i) {
          final name = keys[i];
          final trks = artists[name]!;
          final first = trks.isNotEmpty ? trks.first : null;
          return ListTile(
            leading: ClipOval(child: AlbumArt(
              artUri: first?.artUri, filePath: first?.filePath,
              seed: name, size: 46, radius: 23,
            )),
            title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: kFg3),
            onTap: () => Get.to(() => ArtistDetailScreen(artistName: name)),
            onLongPress: () => _showArtistMenu(name),
          );
        },
      );
    });
  }

  Widget _playlists() {
    return Obx(() {
      final lib = LibraryController.inst;
      final pls = lib.playlists;

      final useGrid = _gridLayout['playlists'] ?? true;

      return Stack(children: [
        pls.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.playlist_add, color: kFg3, size: 48),
                const SizedBox(height: 12),
                const Text('No playlists yet', style: TextStyle(color: kFg1, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextButton.icon(
                  icon: const Icon(Icons.add, color: kBrandOrange),
                  label: const Text('Create playlist', style: TextStyle(color: kBrandOrange)),
                  onPressed: () => _createPlaylist(),
                ),
              ]))
            : useGrid
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.82,
                    crossAxisSpacing: 12, mainAxisSpacing: 12,
                  ),
                  itemCount: pls.length,
                  itemBuilder: (ctx, i) {
                    final pl = pls[i];
                    final trks = lib.playlistTracks(pl);
                    final first = trks.isNotEmpty ? trks.first : null;
                    return GestureDetector(
                      onTap: () => Get.to(() => PlaylistDetailScreen(playlist: pl)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: kBg1, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kBorder),
                        ),
                        child: Column(children: [
                          Expanded(child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            child: AlbumArt(artUri: first?.artUri, filePath: first?.filePath, seed: pl.name, size: double.infinity, radius: 0),
                          )),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(pl.name, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: pls.length,
                  itemBuilder: (ctx, i) {
                    final pl = pls[i];
                    final trks = lib.playlistTracks(pl);
                    final first = trks.isNotEmpty ? trks.first : null;
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AlbumArt(artUri: first?.artUri, filePath: first?.filePath, seed: pl.name, size: 48, radius: 8),
                      ),
                      title: Text(pl.name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, color: kFg3),
                      onTap: () => Get.to(() => PlaylistDetailScreen(playlist: pl)),
                    );
                  },
                ),
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: kBrandOrange,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _createPlaylist(),
          ),
        ),
      ]);
    });
  }

  void _createPlaylist() {
    final ctrl = TextEditingController();
    showDialog(
      context: Get.context!,
      builder: (_) => AlertDialog(
        backgroundColor: kBg1,
        title: const Text('New playlist', style: TextStyle(color: kFg1)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: kFg1),
          decoration: const InputDecoration(
            hintText: 'Playlist name…',
            hintStyle: TextStyle(color: kFg3),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBrandOrange)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: kBrandOrange)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: kFg2))),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) LibraryController.inst.createPlaylist(name);
              Get.back();
            },
            child: const Text('Create', style: TextStyle(color: kBrandOrange)),
          ),
        ],
      ),
    );
  }

  Widget _lovedList() {
    return Obx(() {
      final lib    = LibraryController.inst;
      final loved  = lib.tracks.where((t) => t.loved).toList();
      if (loved.isEmpty) {
        return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.favorite_border, color: kFg3, size: 48),
          const SizedBox(height: 12),
          const Text('No loved tracks', style: TextStyle(color: kFg1, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Tap ♥ on any track to add it here', style: TextStyle(color: kFg2, fontSize: 12)),
        ]));
      }
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            const Icon(Icons.favorite, color: kBrandCoral, size: 14),
            const SizedBox(width: 6),
            Text('${loved.length} loved tracks', style: const TextStyle(color: kFg2, fontSize: 11, letterSpacing: 0.5)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                final q = [...loved]..shuffle();
                PlayerController.inst.playTrack(q.first, queue: q);
                Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: kBrandCoral.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kBrandCoral.withAlpha(80)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shuffle, color: kBrandCoral, size: 12),
                  SizedBox(width: 4),
                  Text('Shuffle', style: TextStyle(color: kBrandCoral, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: loved.length,
          itemBuilder: (ctx, i) => TrackTile(
            track: loved[i],
            onTap: () {
              PlayerController.inst.playTrack(loved[i], queue: loved);
              Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
            },
          ),
        )),
      ]);
    });
  }

  Widget _scanningState() {
    return Obx(() {
      final lib = LibraryController.inst;
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: kBrandOrange, strokeWidth: 3),
          const SizedBox(height: 20),
          Text(lib.scanPhase.value, style: const TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (lib.scanProgress.value > 0)
            LinearProgressIndicator(value: lib.scanProgress.value, color: kBrandOrange, backgroundColor: kBorder),
        ]),
      ));
    });
  }

  Widget _emptyState() {
    return Obx(() {
      final scanning = LibraryController.inst.isScanning.value;
      if (scanning) return _scanningState();
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.music_off, color: kFg3, size: 56),
          const SizedBox(height: 16),
          const Text('No music yet', style: TextStyle(color: kFg1, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Scan your device or choose folders to include', textAlign: TextAlign.center, style: TextStyle(color: kFg2, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Scan device'),
            style: ElevatedButton.styleFrom(backgroundColor: kBrandOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
            onPressed: () => LibraryController.inst.scanLibrary(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_special, color: kFg2),
            label: const Text('Choose folders', style: TextStyle(color: kFg2)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: kBorder), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            onPressed: () => Get.to(() => const FolderPickerScreen()),
          ),
        ]),
      ));
    });
  }

  void _showLibraryMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.search, color: kBrandOrange),
          title: const Text('Scan device', style: TextStyle(color: kFg1)),
          onTap: () { Get.back(); LibraryController.inst.scanLibrary(); },
        ),
        ListTile(
          leading: const Icon(Icons.folder_special, color: kBrandOrange),
          title: const Text('Music folders', style: TextStyle(color: kFg1)),
          onTap: () { Get.back(); Get.to(() => const FolderPickerScreen()); },
        ),
        ListTile(
          leading: const Icon(Icons.sort, color: kFg2),
          title: const Text('Sort', style: TextStyle(color: kFg1)),
          onTap: () { Get.back(); _showSortSheet(); },
        ),
        ListTile(
          leading: const Icon(Icons.bar_chart, color: kFg2),
          title: const Text('Library analytics', style: TextStyle(color: kFg1)),
          onTap: () { Get.back(); Get.to(() => const AnalyticsScreen()); },
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  // ── Context menus ────────────────────────────────────────────────────────

  void _showArtistMenu(String name) {
    final lib  = LibraryController.inst;
    final trks = lib.artists[name] ?? [];
    showModalBottomSheet(
      context: context, backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: kBrandOrange.withAlpha(30),
                child: Text(name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(color: kBrandOrange, fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
            ])),
          ]),
        ),
        const Divider(color: kBorder, height: 1),
        _mItem(Icons.play_arrow, 'Play all', () {
          if (trks.isEmpty) return;
          PlayerController.inst.playTrack(trks.first, queue: trks);
          Get.back();
          Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
        }),
        _mItem(Icons.shuffle, 'Shuffle artist', () {
          if (trks.isEmpty) return;
          final q = trks.toList()..shuffle();
          PlayerController.inst.playTrack(q.first, queue: q);
          Get.back();
          Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
        }),
        _mItem(Icons.queue_music, 'Add all to queue', () {
          for (final t in trks) AuradecAudioHandler.inst.addToQueue(t);
          Get.back();
        }),
        _mItem(Icons.radio, 'Start artist radio', () { Get.back(); }),
        _mItem(Icons.info_outline, 'Artist info & bio', () {
          Get.back();
          Get.to(() => ArtistDetailScreen(artistName: name));
        }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showAlbumMenu(String name, List<Track> trks) {
    final first = trks.isNotEmpty ? trks.first : null;
    showModalBottomSheet(
      context: context, backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8),
                child: AlbumArt(artUri: first?.artUri, filePath: first?.filePath,
                    seed: name, size: 52, radius: 8)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${first?.artist ?? ''} · ${trks.length} tracks',
                  style: const TextStyle(color: kFg2, fontSize: 11)),
            ])),
          ]),
        ),
        const Divider(color: kBorder, height: 1),
        _mItem(Icons.play_arrow, 'Play album', () {
          if (trks.isEmpty) return;
          PlayerController.inst.playTrack(trks.first, queue: trks);
          Get.back();
          Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
        }),
        _mItem(Icons.shuffle, 'Shuffle album', () {
          final q = trks.toList()..shuffle();
          if (q.isEmpty) return;
          PlayerController.inst.playTrack(q.first, queue: q);
          Get.back();
          Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
        }),
        _mItem(Icons.queue_music, 'Add to queue', () {
          for (final t in trks) AuradecAudioHandler.inst.addToQueue(t);
          Get.back();
        }),
        if (first != null)
          _mItem(Icons.mic_none, 'Go to artist', () {
            Get.back();
            Get.to(() => ArtistDetailScreen(artistName: first.artist));
          }),
        _mItem(Icons.info_outline, 'Album info & credits', () {
          Get.back();
          Get.to(() => AlbumDetailScreen(albumName: name, tracks: trks));
        }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Widget _mItem(IconData icon, String label, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: kFg2, size: 20),
    title: Text(label, style: const TextStyle(color: kFg1, fontSize: 14)),
    onTap: onTap, dense: true, minLeadingWidth: 20,
  );
}

