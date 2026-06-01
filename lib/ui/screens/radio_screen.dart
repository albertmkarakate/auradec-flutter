import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import 'now_playing_screen.dart';

// Stream URLs: null = coming soon
// Using publicly available free internet radio streams.

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});
  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _stationGenre = 'All';
  String _artistQuery = '';

  static const _stations = [
    _Station('Lagos Heat',      'World',      '🇳🇬', Color(0xFFFF5C1A), 12480, 128, 'Burna Boy — Last Last',
        'https://stream.zeno.fm/f3wvbbqmdg8uv'),
    _Station('Soweto Pulse',    'Electronic', '🇿🇦', Color(0xFF29F89E), 8210,  128, 'Kabza — Imithandazo',
        null),
    _Station('Accra Jazz Club', 'Jazz/Soul',  '🇬🇭', Color(0xFFFF4D6A), 5120,  128, 'Ebo Taylor — Love and Death',
        null),
    _Station('Nairobi Sundown', 'World',      '🇰🇪', Color(0xFF60A5FA), 6730,  128, 'Sauti Sol — Suzanna',
        null),
    _Station('Midnight Ambient','Ambient',    '🌍', Color(0xFF34D399), 4410,  128, 'Groove Salad · SomaFM',
        'https://ice4.somafm.com/groovesalad-128-mp3'),
    _Station('Drone Zone',      'Ambient',    '🌌', Color(0xFF34D399), 3200,  128, 'Drone Zone · SomaFM',
        'https://ice4.somafm.com/dronezone-128-mp3'),
    _Station('BBC World',       'Talk',       '🇬🇧', Color(0xFFFBBF24), 42000, 96,  'BBC World Service',
        'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service'),
    _Station('Afrobeats 247',   'World',      '🇳🇬', Color(0xFFFF5C1A), 18340, 128, 'Wizkid — Essence',
        null),
    _Station('Piano House ZA',  'Electronic', '🇿🇦', Color(0xFFA78BFA), 7120,  128, 'DBN Gogo — Possible',
        null),
    _Station('Highlife FM',     'World',      '🇬🇭', Color(0xFFFBBF24), 3880,  128, 'KK Fosu — Obaa Hemaa',
        null),
  ];

  static const _genres = [
    _GenreCard('Afrobeats',  Color(0xFFFF5C1A), '🔥', 'Top Afrobeats tracks non-stop'),
    _GenreCard('Amapiano',   Color(0xFF29F89E), '🎹', 'Deep SA piano house'),
    _GenreCard('Afro-soul',  Color(0xFFF5B32A), '🌙', 'Soulful African R&B vibes'),
    _GenreCard('Highlife',   Color(0xFFFF4D6A), '🎺', 'Classic West African highlife'),
    _GenreCard('Hip-hop',    Color(0xFFA78BFA), '🎤', 'Global hip-hop mix'),
    _GenreCard('Electronic', Color(0xFF60A5FA), '⚡', 'Electronic & dance'),
    _GenreCard('Dancehall',  Color(0xFF34D399), '🌴', 'Caribbean riddim heat'),
    _GenreCard('Jazz/Soul',  Color(0xFFFBBF24), '🎷', 'Jazz, soul & neo-soul'),
  ];

  static const _genreFilters = ['All', 'World', 'Electronic', 'Jazz/Soul', 'Ambient', 'Hip-hop'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: Column(children: [
        _header(),
        _tabBar(),
        Expanded(child: TabBarView(controller: _tabs, children: [
          _stationsTab(),
          _genresTab(),
          _artistRadioTab(),
        ])),
      ])),
    );
  }

  Widget _header() {
    return Container(
      color: kBg1,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: const Row(children: [
        Icon(Icons.radio, color: kBrandOrange, size: 22),
        SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Radio', style: TextStyle(color: kFg1, fontSize: 22,
              fontWeight: FontWeight.w800)),
          Text('LIVE STATIONS & SMART RADIO',
              style: TextStyle(color: kBrandGold, fontSize: 7, letterSpacing: 2.5)),
        ]),
      ]),
    );
  }

  Widget _tabBar() {
    return Container(
      color: kBg1,
      child: TabBar(
        controller: _tabs,
        labelColor: Colors.white,
        unselectedLabelColor: kFg2,
        indicatorColor: kBrandOrange,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        tabs: const [Tab(text: 'Stations'), Tab(text: 'Genres'), Tab(text: 'Artist')],
      ),
    );
  }

  // ── Stations ──────────────────────────────────────────────────────

  Widget _stationsTab() {
    return Column(children: [
      _genreFilterBar(),
      Expanded(child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _stations
            .where((s) => _stationGenre == 'All' || s.genre == _stationGenre)
            .map(_stationCard)
            .toList(),
      )),
    ]);
  }

  Widget _genreFilterBar() {
    return SizedBox(height: 44, child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _genreFilters.length,
      itemBuilder: (_, i) {
        final g = _genreFilters[i];
        final active = _stationGenre == g;
        return GestureDetector(
          onTap: () => setState(() => _stationGenre = g),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: active ? kBrandOrange.withAlpha(25) : kBg2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: active ? kBrandOrange : kBorder),
            ),
            child: Text(g, style: TextStyle(
              color: active ? kBrandOrange : kFg2,
              fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
          ),
        );
      },
    ));
  }

  Widget _stationCard(_Station s) {
    final live = s.streamUrl != null;
    return InkWell(
      onTap: () {
        if (!live) { _snack('Stream coming soon — ${s.name}'); return; }
        PlayerController.inst.playRadio(
          url: s.streamUrl!, name: s.name, genre: s.genre, bitrate: s.bitrate);
        Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kBg1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [s.color.withAlpha(80), s.color.withAlpha(30)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Center(child: Text(s.flag, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(s.nowPlaying, style: TextStyle(color: kFg2, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: s.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: s.color.withAlpha(60)),
                ),
                child: Text(s.genre, style: TextStyle(color: s.color, fontSize: 8, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text('${_fmt(s.listeners)} listeners · ${s.bitrate}kbps',
                  style: const TextStyle(color: kFg3, fontSize: 9)),
            ]),
          ])),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: live ? s.color.withAlpha(50) : s.color.withAlpha(20),
                border: Border.all(color: s.color.withAlpha(live ? 160 : 60)),
              ),
              child: Icon(Icons.play_arrow, color: live ? s.color : s.color.withAlpha(80), size: 20),
            ),
            if (live) Text('LIVE', style: TextStyle(color: s.color, fontSize: 6, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
        ]),
      ),
    );
  }

  // ── Genres ────────────────────────────────────────────────────────

  Widget _genresTab() {
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(12),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: _genres.map(_genreCard).toList(),
    );
  }

  Widget _genreCard(_GenreCard g) {
    return GestureDetector(
      onTap: () => _playGenreRadio(g.name),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [g.color.withAlpha(70), g.color.withAlpha(25)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(color: g.color.withAlpha(50)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(g.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(g.name, style: TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(g.desc, style: const TextStyle(color: kFg2, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  void _playGenreRadio(String genre) {
    final lib = LibraryController.inst;
    final ql = genre.toLowerCase();
    final matching = lib.tracks.where((t) =>
      t.genre.toLowerCase().contains(ql) ||
      t.title.toLowerCase().contains(ql) ||
      t.artist.toLowerCase().contains(ql)
    ).toList();

    if (matching.isEmpty) {
      _snack('No "$genre" tracks in library — add some first');
      return;
    }
    matching.shuffle();
    PlayerController.inst.playTrack(matching.first, queue: matching);
    Get.to(() => const NowPlayingScreen());
  }

  // ── Artist Radio ─────────────────────────────────────────────────

  Widget _artistRadioTab() {
    return Obx(() {
      final lib = LibraryController.inst;
      final filtered = _artistQuery.isEmpty
          ? (lib.artists.keys.toList()..sort())
          : (lib.artists.keys.where((a) => a.toLowerCase().contains(_artistQuery.toLowerCase())).toList()..sort());

      return Column(children: [
        Container(
          color: kBg1, padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            height: 42,
            decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(21), border: Border.all(color: kBorder)),
            child: TextField(
              style: const TextStyle(color: kFg1, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search artists in library…',
                hintStyle: const TextStyle(color: kFg3, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: kFg3, size: 18),
                suffixIcon: _artistQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, color: kFg2, size: 14), onPressed: () => setState(() => _artistQuery = ''))
                    : null,
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
              onChanged: (v) => setState(() => _artistQuery = v),
            ),
          ),
        ),
        if (filtered.isEmpty)
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.mic_off, color: kFg3, size: 40),
            const SizedBox(height: 10),
            Text(_artistQuery.isEmpty ? 'Library is empty' : 'No artists matching "$_artistQuery"',
                style: const TextStyle(color: kFg2, fontSize: 13)),
          ])))
        else
          Expanded(child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final name = filtered[i];
              final trks = lib.artists[name] ?? [];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: kBrandOrange.withAlpha(30),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: kBrandOrange, fontWeight: FontWeight.w700)),
                ),
                title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14)),
                subtitle: Text('${trks.length} tracks — tap for artist radio',
                    style: const TextStyle(color: kFg2, fontSize: 11)),
                trailing: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: kBrandOrange),
                  child: const Icon(Icons.shuffle, color: Colors.white, size: 16),
                ),
                onTap: () {
                  if (trks.isEmpty) return;
                  final q = [...trks]..shuffle();
                  PlayerController.inst.playTrack(q.first, queue: q);
                  Get.to(() => const NowPlayingScreen());
                },
              );
            },
          )),
      ]);
    });
  }

  void _snack(String msg) {
    Get.snackbar('', msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: kBg2,
      colorText: kFg1,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
      duration: const Duration(seconds: 2),
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      messageText: Text(msg, style: const TextStyle(color: kFg1, fontSize: 13)),
      titleText: const SizedBox.shrink(),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _Station {
  final String name, genre, flag, nowPlaying;
  final Color color;
  final int listeners, bitrate;
  final String? streamUrl;
  const _Station(this.name, this.genre, this.flag, this.color, this.listeners, this.bitrate, this.nowPlaying, this.streamUrl);
}

class _GenreCard {
  final String name, emoji, desc;
  final Color color;
  const _GenreCard(this.name, this.color, this.emoji, this.desc);
}
