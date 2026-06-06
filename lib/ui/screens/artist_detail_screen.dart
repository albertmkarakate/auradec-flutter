import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/track.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/player_controller.dart';
import '../../services/artist_profile_service.dart';
import '../widgets/album_art.dart';
import '../widgets/bulk_edit_sheet.dart';
import '../widgets/track_tile.dart';
import '../widgets/musicbrainz_sheet.dart';
import 'now_playing_screen.dart';
import 'album_detail_screen.dart';

// ── Prefs key ─────────────────────────────────────────────────────────────────
String _imgKey(String name) =>
    'artist_img_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

class ArtistDetailScreen extends StatefulWidget {
  final String artistName;
  const ArtistDetailScreen({super.key, required this.artistName});
  @override State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // bio
  String? _bio;
  bool _bioLoading = true;

  // artist image
  String? _customImageUrl;   // user-picked (persisted)
  String? _wikiImageUrl;     // from Wikipedia
  ArtistProfile? _profile;   // rich profile from ArtistProfileService
  bool _profileLoading = false;

  // image search
  bool   _imgSearching = false;
  List<String> _imgResults = [];
  String? _imgError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadCustomImage();
    _fetchWiki();
    _loadProfile();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // ── Loaders ───────────────────────────────────────────────────────────────

  Future<void> _loadCustomImage() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_imgKey(widget.artistName));
    if (mounted && url != null) setState(() => _customImageUrl = url);
  }

  Future<void> _saveCustomImage(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_imgKey(widget.artistName), url);
    if (mounted) setState(() => _customImageUrl = url);
  }

  Future<void> _clearCustomImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_imgKey(widget.artistName));
    if (mounted) setState(() => _customImageUrl = null);
  }

  Future<void> _loadProfile({bool force = false}) async {
    if (_profileLoading) return;
    if (mounted) setState(() => _profileLoading = true);
    try {
      final lib       = LibraryController.inst;
      final tracks    = lib.artists[widget.artistName] ?? <Track>[];
      // Gather hints from local library for better disambiguation
      final genres    = tracks.map((t) => t.genre).where((g) => g.isNotEmpty).toSet().toList();
      final years     = tracks.map((t) => t.year).where((y) => y > 0).toList();

      final p = await ArtistProfileService.inst.getProfile(
        widget.artistName, force: force, hintGenres: genres, hintYears: years);
      if (mounted) setState(() {
        _profile = p;
        if (_bio == null && p?.bio != null) _bio = p!.bio;
        if (_wikiImageUrl == null && p?.thumb != null) _wikiImageUrl = p!.thumb;
      });
    } catch (_) {}
    if (mounted) setState(() => _profileLoading = false);
  }

  // ── Disambiguation picker ─────────────────────────────────────────────────

  Future<void> _showDisambiguationPicker() async {
    // Show loading snack
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Fetching artist candidates…'),
      duration: Duration(seconds: 2),
      backgroundColor: kBg2, behavior: SnackBarBehavior.floating,
    ));

    final candidates = await ArtistProfileService.inst.getCandidates(widget.artistName);
    if (!mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No candidates found on MusicBrainz'),
        backgroundColor: kBg2, behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final pinned = await ArtistProfileService.inst.getPinnedMbid(widget.artistName);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: kBg1, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, color: kBrandGold, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Select correct "${widget.artistName}"',
                    style: const TextStyle(color: kFg1, fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
            const Divider(color: kBorder, height: 1),
            Expanded(child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: candidates.length,
              itemBuilder: (_, i) {
                final c    = candidates[i];
                final isPin = c.mbid == pinned;
                return ListTile(
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isPin ? kBrandOrange.withAlpha(30) : kBg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPin ? kBrandOrange : kBorder)),
                    child: Center(child: Text(
                      c.country.isNotEmpty ? c.country : '?',
                      style: TextStyle(
                        color: isPin ? kBrandOrange : kFg2,
                        fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'Barlow'))),
                  ),
                  title: Row(children: [
                    Flexible(child: Text(c.name,
                        style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600))),
                    if (isPin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: kBrandOrange.withAlpha(30), borderRadius: BorderRadius.circular(3)),
                        child: const Text('pinned',
                            style: TextStyle(color: kBrandOrange, fontSize: 9, fontFamily: 'Barlow'))),
                    ],
                  ]),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (c.disambiguation.isNotEmpty)
                      Text(c.disambiguation,
                          style: const TextStyle(color: kFg2, fontSize: 12)),
                    Row(children: [
                      if (c.type.isNotEmpty)
                        Text(c.type, style: const TextStyle(color: kFg3, fontSize: 10, fontFamily: 'Barlow')),
                      if (c.type.isNotEmpty && c.beginYear != null)
                        const Text(' · ', style: TextStyle(color: kFg3, fontSize: 10)),
                      if (c.beginYear != null)
                        Text('b. ${c.beginYear!.substring(0, 4)}',
                            style: const TextStyle(color: kFg3, fontSize: 10, fontFamily: 'Barlow')),
                      if (c.tags.isNotEmpty) ...[
                        const Text(' · ', style: TextStyle(color: kFg3, fontSize: 10)),
                        Flexible(child: Text(c.tags.take(3).join(', '),
                            style: const TextStyle(color: kFg3, fontSize: 10, fontFamily: 'Barlow'),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ]),
                  ]),
                  trailing: const Icon(Icons.chevron_right, color: kFg3, size: 18),
                  onTap: () async {
                    Get.back();
                    final lib    = LibraryController.inst;
                    final tracks = lib.artists[widget.artistName] ?? <Track>[];
                    final genres = tracks.map((t) => t.genre).where((g) => g.isNotEmpty).toList();
                    final years  = tracks.map((t) => t.year).where((y) => y > 0).toList();
                    if (mounted) setState(() { _profile = null; _profileLoading = true; });
                    final p = await ArtistProfileService.inst.pinMbid(
                      widget.artistName, c.mbid, hintGenres: genres, hintYears: years);
                    if (mounted) setState(() {
                      _profile = p;
                      _profileLoading = false;
                      if (p?.bio != null) _bio = p!.bio;
                      if (p?.thumb != null) _wikiImageUrl = p!.thumb;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Pinned to ${c.name}${c.disambiguation.isNotEmpty ? ' (${c.disambiguation})' : ''}'),
                        backgroundColor: kBg2, behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ));
                    }
                  },
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  Future<void> _fetchWiki() async {
    try {
      final res = await http.get(Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(widget.artistName)}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['type'] != 'disambiguation') {
          if (mounted) setState(() {
            _bio = j['extract'] as String?;
            final thumb = j['thumbnail'] as Map?;
            _wikiImageUrl = thumb?['source'] as String?;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _bioLoading = false);
  }

  // ── Image search (DuckDuckGo) ─────────────────────────────────────────────

  Future<void> _searchImages() async {
    setState(() { _imgSearching = true; _imgResults = []; _imgError = null; });
    final query = '${widget.artistName} musician artist photo';
    final results = <String>[];

    // 0 — Profile images (TheAudioDB fanart, thumb, banner)
    if (_profile != null) {
      results.addAll(ArtistProfileService.inst.allImages(_profile!));
    }

    // 1 — Wikipedia thumbnail (already loaded)
    if (_wikiImageUrl != null && !results.contains(_wikiImageUrl!)) results.add(_wikiImageUrl!);

    // 2 — DuckDuckGo image search
    try {
      final encoded = Uri.encodeComponent(query);
      // Get vqd token
      final initRes = await http.get(
        Uri.parse('https://duckduckgo.com/?q=$encoded&iar=images&iax=images&ia=images'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        }).timeout(const Duration(seconds: 10));

      String? vqd;
      final vqdMatch = RegExp(r'''vqd=["']?([^"'&\s]+)["']?''').firstMatch(initRes.body);
      vqd = vqdMatch?.group(1);

      if (vqd != null) {
        final imgRes = await http.get(
          Uri.parse('https://duckduckgo.com/i.js?q=$encoded&vqd=${Uri.encodeComponent(vqd)}&o=json&p=1'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36',
            'Referer': 'https://duckduckgo.com/',
            'Accept': 'application/json',
          }).timeout(const Duration(seconds: 10));

        if (imgRes.statusCode == 200) {
          final data = jsonDecode(imgRes.body) as Map?;
          final list = (data?['results'] as List?) ?? [];
          for (final r in list.take(24)) {
            final url = (r as Map)['image'] as String?;
            if (url != null && url.startsWith('http')) results.add(url);
          }
        }
      }
    } catch (_) {}

    // 3 — Bing scrape fallback
    if (results.length < 6) {
      try {
        final bRes = await http.get(
          Uri.parse('https://www.bing.com/images/search?q=${Uri.encodeComponent(query)}&count=20&mkt=en-US'),
          headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36'})
            .timeout(const Duration(seconds: 10));
        final matches = RegExp(r'"murl":"([^"]+)"').allMatches(bRes.body);
        for (final m in matches.take(16)) {
          final url = m.group(1);
          if (url != null && url.startsWith('http')) results.add(url);
        }
      } catch (_) {}
    }

    if (mounted) setState(() {
      _imgResults = results.toSet().toList();
      _imgSearching = false;
      if (results.isEmpty) _imgError = 'No images found. Try a different search.';
    });
  }

  // ── Image picker sheet ────────────────────────────────────────────────────

  void _showImagePicker() {
    _searchImages();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        // forward local state updates back to parent so grid refreshes
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) => Container(
            decoration: const BoxDecoration(
              color: kBg1, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              // Handle
              Center(child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(children: [
                  const Icon(Icons.image_search, color: kBrandGold, size: 20),
                  const SizedBox(width: 8),
                  Text('Choose Artist Photo', style: const TextStyle(
                    color: kFg1, fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_customImageUrl != null)
                    TextButton(
                      onPressed: () { _clearCustomImage(); Get.back(); },
                      child: const Text('Reset', style: TextStyle(color: kBrandCoral, fontSize: 12))),
                  TextButton(
                    onPressed: () { setState(() {}); _searchImages(); },
                    child: const Text('Refresh', style: TextStyle(color: kBrandGold, fontSize: 12))),
                ]),
              ),
              const Divider(color: kBorder, height: 1),
              // Grid
              Expanded(child: _buildImgGrid(scroll)),
            ]),
          ),
        );
      }),
    );
  }

  Widget _buildImgGrid(ScrollController scroll) {
    return AnimatedBuilder(
      animation: Listenable.merge([]),
      builder: (_, __) {
        if (_imgSearching && _imgResults.isEmpty) {
          return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: kBrandGold, strokeWidth: 2),
            SizedBox(height: 12),
            Text('Searching images…', style: TextStyle(color: kFg2, fontSize: 13)),
          ]));
        }
        if (_imgError != null && _imgResults.isEmpty) {
          return Center(child: Text(_imgError!, style: const TextStyle(color: kFg3, fontSize: 13)));
        }
        return GridView.builder(
          controller: scroll,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: _imgResults.length + (_imgSearching ? 3 : 0),
          itemBuilder: (_, i) {
            if (i >= _imgResults.length) {
              return Container(
                decoration: BoxDecoration(color: kBg2, borderRadius: BorderRadius.circular(10)),
                child: const Center(child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kBrandGold))));
            }
            final url = _imgResults[i];
            final isCurrent = url == _customImageUrl;
            return GestureDetector(
              onTap: () { _saveCustomImage(url); Get.back(); },
              child: Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(url, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: kBg2,
                      child: const Icon(Icons.broken_image, color: kFg3, size: 24)))),
                if (isCurrent)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: kBrandGold.withOpacity(0.3),
                      border: Border.all(color: kBrandGold, width: 2)),
                    child: const Center(child: Icon(Icons.check_circle, color: kBrandGold, size: 28))),
              ]),
            );
          },
        );
      },
    );
  }

  // ── Actions button sheet ──────────────────────────────────────────────────

  void _showArtistActions(List<Track> tracks) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 36, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(widget.artistName, style: const TextStyle(
            color: kFg1, fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const Divider(color: kBorder, height: 1),
        _aItem(Icons.image_outlined, 'Change artist photo', () { Get.back(); _showImagePicker(); }),
        if (_customImageUrl != null)
          _aItem(Icons.hide_image_outlined, 'Remove custom photo', () { Get.back(); _clearCustomImage(); },
              color: kBrandCoral),
        _aItem(Icons.play_arrow_rounded, 'Play all tracks', () {
          Get.back();
          if (tracks.isNotEmpty) {
            PlayerController.inst.playTrack(tracks.first, queue: List.from(tracks));
            Get.to(() => const NowPlayingScreen());
          }
        }),
        _aItem(Icons.shuffle_rounded, 'Shuffle all', () {
          Get.back();
          if (tracks.isNotEmpty) {
            final s = [...tracks]..shuffle();
            PlayerController.inst.playTrack(s.first, queue: s);
            Get.to(() => const NowPlayingScreen());
          }
        }),
        _aItem(Icons.edit_note, 'Edit tags for all tracks', () {
          Get.back();
          if (tracks.isNotEmpty) _bulkEditAll(tracks);
        }),
        _aItem(Icons.manage_search, 'MusicBrainz lookup', () {
          Get.back();
          if (tracks.isNotEmpty) showMusicBrainzSheet(context, tracks.first);
        }, color: kBrandGreen),
        _aItem(Icons.refresh_rounded, 'Refresh artist profile', () {
          Get.back();
          _loadProfile(force: true);
        }),
        _aItem(Icons.swap_horiz_rounded, 'Wrong artist? Pick manually', () {
          Get.back();
          _showDisambiguationPicker();
        }, color: kBrandGold),
        const SizedBox(height: 8),
      ])),
    );
  }

  Widget _aItem(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
    leading: Icon(icon, color: color ?? kFg2, size: 20),
    title: Text(label, style: TextStyle(color: color ?? kFg1, fontSize: 14)),
    onTap: onTap, dense: true, minLeadingWidth: 20,
  );

  Future<void> _bulkEditAll(List<Track> tracks) async {
    final n = await showBulkEditSheet(context, tracks);
    if (!mounted) return;
    final msg = n < 0
        ? 'Storage permission needed to write tags'
        : (n > 0 ? 'Updated $n track${n == 1 ? '' : 's'}' : 'No changes written');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: kBg2,
      behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lib    = LibraryController.inst;
      final tracks = (lib.artists[widget.artistName] ?? <Track>[]).toList();
      final albums = lib.albums.entries
          .where((e) => e.value.any((t) => t.artist.contains(widget.artistName)))
          .toList()
        ..sort((a, b) => (b.value.firstOrNull?.year ?? 0).compareTo(a.value.firstOrNull?.year ?? 0));

      // Pick best image: custom → profile fanart → wiki/thumb → album art seed
      final heroImageUrl = _customImageUrl
          ?? _profile?.fanart
          ?? _profile?.thumb
          ?? _wikiImageUrl;

      return Scaffold(
        backgroundColor: kBg0,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              expandedHeight: 300, pinned: true, backgroundColor: kBg0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: kFg1), onPressed: () => Get.back()),
              actions: [
                // Follow button
                Obx(() {
                  final lib = LibraryController.inst;
                  final following = lib.isFollowing(widget.artistName);
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: GestureDetector(
                      onTap: () async {
                        await lib.toggleFollowArtist(widget.artistName);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(lib.isFollowing(widget.artistName)
                                ? 'Following ${widget.artistName}'
                                : 'Unfollowed ${widget.artistName}'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: kBg2,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: following ? kBrandOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: following ? kBrandOrange : kBorder.withAlpha(100)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(following ? Icons.favorite : Icons.favorite_border,
                              color: following ? Colors.white : kFg2, size: 13),
                          const SizedBox(width: 5),
                          Text(following ? 'Following' : 'Follow',
                              style: TextStyle(
                                color: following ? Colors.white : kFg2,
                                fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Barlow')),
                        ]),
                      ),
                    ),
                  );
                }),
                // ＋ actions button
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _showArtistActions(tracks),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kBrandGold,
                      ),
                      child: const Icon(Icons.add, color: Colors.black, size: 20),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  // Hero image
                  heroImageUrl != null
                    ? Image.network(heroImageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => AlbumArt(
                          artUri: tracks.isNotEmpty ? tracks.first.artUri : null,
                          filePath: tracks.isNotEmpty ? tracks.first.filePath : null,
                          seed: widget.artistName, size: double.infinity, radius: 0))
                    : AlbumArt(
                        artUri: tracks.isNotEmpty ? tracks.first.artUri : null,
                        filePath: tracks.isNotEmpty ? tracks.first.filePath : null,
                        seed: widget.artistName, size: double.infinity, radius: 0),
                  // Gradient
                  Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(40), Colors.black.withAlpha(130), kBg0],
                    stops: const [0.0, 0.5, 1.0],
                  ))),
                  // Name + stats + edit hint
                  Positioned(left: 20, right: 20, bottom: 16,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.artistName, style: const TextStyle(
                          color: kFg1, fontSize: 30, fontWeight: FontWeight.w800,
                          fontFamily: 'Syne', letterSpacing: -0.5,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
                        const SizedBox(height: 4),
                        Row(children: [
                          if (tracks.isNotEmpty) ...[
                            const Icon(Icons.music_note, color: kFg3, size: 11),
                            const SizedBox(width: 3),
                            Text('${tracks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 11)),
                            const Text(' · ', style: TextStyle(color: kFg3, fontSize: 11)),
                          ],
                          if (albums.isNotEmpty) ...[
                            const Icon(Icons.album, color: kFg3, size: 11),
                            const SizedBox(width: 3),
                            Text('${albums.length} albums', style: const TextStyle(color: kFg2, fontSize: 11)),
                          ],
                          if (_customImageUrl != null) ...[
                            const Text(' · ', style: TextStyle(color: kFg3, fontSize: 11)),
                            const Icon(Icons.camera_alt, color: kBrandGold, size: 11),
                            const SizedBox(width: 3),
                            const Text('custom photo', style: TextStyle(color: kBrandGold, fontSize: 10)),
                          ],
                        ]),
                        if (_profile?.disambiguation != null || _profile?.country != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(children: [
                              if (_profile!.country != null) ...[
                                Text(_profile!.country!, style: const TextStyle(
                                    color: kBrandGold, fontSize: 10, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
                                const Text(' · ', style: TextStyle(color: kFg3, fontSize: 10)),
                              ],
                              if (_profile!.disambiguation != null)
                                Flexible(child: Text(_profile!.disambiguation!, style: const TextStyle(
                                    color: kFg2, fontSize: 10, fontFamily: 'Barlow'),
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                      ])),
                      // Photo edit button
                      GestureDetector(
                        onTap: _showImagePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: const [
                            Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 14),
                            SizedBox(width: 4),
                            Text('Photo', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ]),
                        ),
                      ),
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
                    labelColor: kFg1, unselectedLabelColor: kFg3,
                    indicatorColor: kBrandOrange, indicatorWeight: 2,
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Barlow'),
                    tabs: const [Tab(text: 'Overview'), Tab(text: 'Discography'), Tab(text: 'Similar'), Tab(text: 'Stats')],
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

  // ── Overview ──────────────────────────────────────────────────────────────

  Widget _overviewTab(List<Track> tracks, List<MapEntry<String, List<Track>>> albums) {
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: [
      // ── Profile genres + stats ───────────────────────────────────────
      if (_profile != null) ...[
        if (_profile!.genres.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Wrap(spacing: 6, runSpacing: 6, children: _profile!.genres.take(8).map((g) =>
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kBrandGold.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: kBrandGold.withAlpha(50))),
                child: Text(g, style: const TextStyle(
                    color: kBrandGold, fontSize: 10, fontFamily: 'Barlow')),
              )).toList()),
          ),
        if (_profile!.listeners != null || _profile!.scrobbles != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              if (_profile!.listeners != null) ...[
                const Icon(Icons.headphones, color: kFg3, size: 11),
                const SizedBox(width: 4),
                Text(_fmtNum(_profile!.listeners!),
                    style: const TextStyle(color: kFg2, fontSize: 11, fontFamily: 'Barlow')),
                const Text(' listeners', style: TextStyle(color: kFg3, fontSize: 11)),
                const SizedBox(width: 16),
              ],
              if (_profile!.scrobbles != null) ...[
                const Icon(Icons.play_circle_outline, color: kFg3, size: 11),
                const SizedBox(width: 4),
                Text(_fmtNum(_profile!.scrobbles!),
                    style: const TextStyle(color: kFg2, fontSize: 11, fontFamily: 'Barlow')),
                const Text(' scrobbles', style: TextStyle(color: kFg3, fontSize: 11)),
              ],
            ]),
          ),
      ],

      // Play / Shuffle
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
        const Padding(padding: EdgeInsets.all(20),
          child: LinearProgressIndicator(color: kBrandOrange, backgroundColor: kBg2))
      else if (_bio != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kBg1, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.auto_stories_outlined, color: kFg3, size: 13),
                const SizedBox(width: 6),
                const Text('BIO', style: TextStyle(color: kFg3, fontSize: 9, letterSpacing: 2, fontFamily: 'Barlow')),
                const Spacer(),
                const Text('Wikipedia', style: TextStyle(color: kFg3, fontSize: 9, fontFamily: 'Barlow')),
              ]),
              const SizedBox(height: 10),
              Text(_bio!, style: const TextStyle(color: kFg2, fontSize: 12, height: 1.7)),
            ]),
          ),
        ),

      // Members (bands)
      if (_profile != null && _profile!.members.isNotEmpty) ...[
        _sectionHead('Members'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: _profile!.members.map((m) =>
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kBg2, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kBorder)),
              child: Text(m, style: const TextStyle(color: kFg1, fontSize: 12)),
            )).toList()),
        ),
      ],

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
      ...(([...tracks]..sort((a, b) => b.plays.compareTo(a.plays))).take(5).map((t) => TrackTile(
        track: t,
        onTap: () { PlayerController.inst.playTrack(t, queue: List.from(tracks)); Get.to(() => const NowPlayingScreen()); },
      ))),
    ]);
  }

  // ── Discography ───────────────────────────────────────────────────────────

  Widget _discographyTab(List<MapEntry<String, List<Track>>> albums, List<Track> tracks) {
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: [
      if (albums.isNotEmpty) ...[
        _sectionHead('Albums'),
        ...albums.map((e) {
          final name = e.key; final trks = e.value;
          final first = trks.isNotEmpty ? trks.first : null;
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: AlbumArt(artUri: first?.artUri, filePath: first?.filePath, seed: name, size: 52, radius: 8)),
            title: Text(name, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('${trks.length} tracks${first != null && first.year > 0 ? ' · ${first.year}' : ''}',
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

  // ── Similar ───────────────────────────────────────────────────────────────

  Widget _similarTab(List<Track> tracks) {
    final lib = LibraryController.inst;
    final myGenres = tracks.map((t) => t.genre).where((g) => g.isNotEmpty).toSet();
    final similar = lib.artists.entries
        .where((e) => e.key != widget.artistName)
        .where((e) => myGenres.isNotEmpty ? e.value.any((t) => myGenres.contains(t.genre)) : true)
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
        final name = similar[i].key; final trks = similar[i].value;
        return GestureDetector(
          onTap: () => Get.to(() => ArtistDetailScreen(artistName: name)),
          child: Column(children: [
            Expanded(child: ClipOval(child: AlbumArt(
              artUri: trks.firstOrNull?.artUri, filePath: trks.firstOrNull?.filePath,
              seed: name, size: double.infinity, radius: 999))),
            const SizedBox(height: 5),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(color: kFg1, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('${trks.length} tracks', style: const TextStyle(color: kFg2, fontSize: 9)),
          ]),
        );
      },
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

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
      ['TRACKS', '${tracks.length}', Icons.music_note],
      ['TOTAL PLAYS', '$totalPlays', Icons.play_arrow],
      ['LISTEN TIME', '${totalMin}m', Icons.timer_outlined],
      ['LOVED', '$loved', Icons.favorite],
    ];

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), children: [
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
        children: statCards.map((c) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kBg1, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
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
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2),
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

  static String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}
