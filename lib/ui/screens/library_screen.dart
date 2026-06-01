import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../widgets/track_tile.dart';
import '../widgets/album_art.dart';
import 'folder_picker_screen.dart';
import 'now_playing_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'playlist_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      final labels = ['tracks', 'albums', 'artists', 'playlists', 'loved'];
      setState(() => _activeTab = labels[_tabs.index]);
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
      ]),
    );
  }

  Widget _logomark() {
    return Container(
      width: 32, height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: kBrandOrange,
      ),
      child: const Icon(Icons.music_note, color: Colors.white, size: 18),
    );
  }

  Widget _toolbarActions() {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.folder_special_outlined, color: kBrandOrange, size: 22),
        onPressed: () => Get.to(() => const FolderPickerScreen()),
        tooltip: 'Music folders',
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
        icon: Icon(_sortAsc ? Icons.sort : Icons.sort, color: kFg2, size: 22),
        tooltip: 'Sort',
        onPressed: () => _showSortSheet(),
      ),
    ]);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('Sort by', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () { setState(() => _sortAsc = !_sortAsc); setS(() {}); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, color: kBrandOrange, size: 14),
                  const SizedBox(width: 4),
                  Text(_sortAsc ? 'A–Z' : 'Z–A', style: const TextStyle(color: kFg1, fontSize: 12)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          ..._SortMode.values.map((m) {
            final labels = {_SortMode.title: 'Title', _SortMode.artist: 'Artist', _SortMode.album: 'Album', _SortMode.dateAdded: 'Date added', _SortMode.duration: 'Duration'};
            final icons  = {_SortMode.title: Icons.sort_by_alpha, _SortMode.artist: Icons.mic, _SortMode.album: Icons.album, _SortMode.dateAdded: Icons.calendar_today, _SortMode.duration: Icons.timer_outlined};
            final active = _sortMode == m;
            return ListTile(
              leading: Icon(icons[m], color: active ? kBrandOrange : kFg2, size: 20),
              title: Text(labels[m]!, style: TextStyle(color: active ? kBrandOrange : kFg1, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
              trailing: active ? const Icon(Icons.check, color: kBrandOrange, size: 18) : null,
              onTap: () { setState(() => _sortMode = m); setS(() {}); },
              dense: true,
            );
          }),
        ]),
      )),
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
    });
  }

  Widget _albumGrid() {
    return Obx(() {
      final albums = LibraryController.inst.albums;
      if (albums.isEmpty) return const SizedBox();
      final keys = albums.keys.toList()..sort();
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.8,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: keys.length,
        itemBuilder: (ctx, i) {
          final name  = keys[i];
          final trks  = albums[name]!;
          return _albumCard(name, trks);
        },
      );
    });
  }

  Widget _albumCard(String name, List<dynamic> tracks) {
    final tList = tracks.cast<dynamic>();
    final artUri = tList.isNotEmpty ? (tList.first as dynamic).artUri as String? : null;
    return GestureDetector(
      onTap: () => Get.to(() => AlbumDetailScreen(albumName: name, tracks: List.from(tList))),
      child: Container(
        decoration: BoxDecoration(
          color: kBg1, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: AlbumArt(artUri: artUri, seed: name, size: double.infinity, radius: 0),
          )),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(color: kFg1, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${tracks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _artistList() {
    return Obx(() {
      final artists = LibraryController.inst.artists;
      final keys    = artists.keys.toList()..sort();
      if (keys.isEmpty) return const SizedBox();
      return ListView.builder(
        itemCount: keys.length,
        itemBuilder: (ctx, i) {
          final name = keys[i];
          final trks = artists[name]!;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: kBrandOrange.withAlpha(30),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: kBrandOrange, fontWeight: FontWeight.w700)),
            ),
            title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14)),
            subtitle: Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: kFg3),
            onTap: () => Get.to(() => ArtistDetailScreen(artistName: name)),
          );
        },
      );
    });
  }

  Widget _playlists() {
    return Obx(() {
      final lib = LibraryController.inst;
      final pls = lib.playlists;

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
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: pls.length,
                itemBuilder: (ctx, i) {
                  final pl = pls[i];
                  final trks = lib.playlistTracks(pl);
                  final artUri = trks.isNotEmpty ? trks.first.artUri : null;
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AlbumArt(artUri: artUri, seed: pl.name, size: 48, radius: 8),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.search, color: kBrandOrange),
          title: const Text('Scan device', style: TextStyle(color: kFg1)),
          onTap: () { Get.back(); LibraryController.inst.scanLibrary(); },
        ),
        ListTile(
          leading: const Icon(Icons.folder_special, color: kBrandOrange),
          title: const Text('Choose music folders', style: TextStyle(color: kFg1)),
          onTap: () { Get.back(); Get.to(() => const FolderPickerScreen()); },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
