import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../controllers/library_controller.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: Obx(() {
        final lib = LibraryController.inst;
        final tracks = lib.tracks;
        final totalPlays = tracks.fold(0, (s, t) => s + t.plays);
        final totalMs = tracks.fold(0, (s, t) => s + t.durationMs * t.plays);
        final totalH = totalMs ~/ 3600000;
        final totalM = (totalMs % 3600000) ~/ 60000;

        // Top artists by plays
        final artistPlays = <String, int>{};
        for (final t in tracks) {
          final a = t.artist.split(RegExp(r'[,&]|feat\.')).first.trim();
          artistPlays[a] = (artistPlays[a] ?? 0) + t.plays;
        }
        final topArtists = artistPlays.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final maxPlays = topArtists.isNotEmpty ? topArtists.first.value : 1;

        // By format
        final codecs = <String, int>{};
        for (final t in tracks) codecs[t.codec] = (codecs[t.codec] ?? 0) + 1;

        return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
          const Text('Analytics', style: TextStyle(color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
          const SizedBox(height: 4),
          const Text('How your library gets listened to.', style: TextStyle(color: kFg2, fontSize: 12)),
          const SizedBox(height: 16),

          // Stats grid
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
            children: [
              _statCard('Tracks',      tracks.length.toString(),        Icons.music_note),
              _statCard('Artists',     lib.artists.length.toString(),   Icons.mic),
              _statCard('Albums',      lib.albums.length.toString(),    Icons.album),
              _statCard('Total plays', totalPlays.toLocaleString(),     Icons.play_arrow),
            ],
          ),
          const SizedBox(height: 12),

          // Listening time
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Listening time'),
            const SizedBox(height: 4),
            Text(totalH > 0 ? '${totalH}h ${totalM}m' : '${totalM}m', style: const TextStyle(color: kFg1, fontSize: 32, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
            Text('All time · avg ${tracks.isNotEmpty ? (totalPlays / tracks.length).toStringAsFixed(1) : "0"} plays/track', style: const TextStyle(color: kFg2, fontSize: 11)),
          ])),
          const SizedBox(height: 10),

          // Top artists bar chart
          if (topArtists.isNotEmpty) _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Most listened'),
            const SizedBox(height: 12),
            ...topArtists.take(8).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(e.key, style: const TextStyle(color: kFg1, fontSize: 13))),
                  Text('${e.value} plays', style: const TextStyle(color: kFg3, fontSize: 10)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(
                  value: maxPlays > 0 ? e.value / maxPlays : 0,
                  backgroundColor: kBorder, color: kBrandOrange, minHeight: 4,
                )),
              ]),
            )),
          ])),
          const SizedBox(height: 10),

          // Format breakdown
          if (codecs.isNotEmpty) Row(children: [
            Expanded(child: _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('By format'),
              const SizedBox(height: 8),
              ...codecs.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: _codecColor(e.key), shape: BoxShape.circle)),
                  Text(e.key, style: const TextStyle(color: kFg2, fontSize: 10)),
                  const Spacer(),
                  Text('${(e.value / tracks.length * 100).round()}%', style: const TextStyle(color: kFg3, fontSize: 10)),
                ]),
              )),
            ]))),
          ]),
        ]);
      })),
    );
  }

  Widget _statCard(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kBg1, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: kBrandOrange, size: 14), const SizedBox(width: 6), Text(label.toUpperCase(), style: const TextStyle(color: kFg3, fontSize: 8, letterSpacing: 1.5))]),
      const Spacer(),
      Text(value, style: const TextStyle(color: kFg1, fontSize: 28, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
    ]),
  );

  Widget _card(Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kBg1, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
    child: child,
  );

  Widget _label(String s) => Text(s.toUpperCase(), style: const TextStyle(color: kBrandGold, fontSize: 8, letterSpacing: 2));

  Color _codecColor(String c) {
    switch (c) { case 'FLAC': return kBrandOrange; case 'MP3': return kBrandGold; case 'M4A': return kBrandGreen; default: return kBrandCoral; }
  }
}

extension _Fmt on int { String toLocaleString() { final s = toString(); final buf = StringBuffer(); for (int i = 0; i < s.length; i++) { if (i > 0 && (s.length - i) % 3 == 0) buf.write(','); buf.write(s[i]); } return buf.toString(); } }
