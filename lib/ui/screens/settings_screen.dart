import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import '../../controllers/library_controller.dart';
import '../../controllers/theme_controller.dart';
import '../screens/folder_picker_screen.dart';
import '../screens/scrobble_sheets.dart';
import '../../services/audio_handler.dart';
import '../../services/scrobble_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('Settings', style: TextStyle(color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
        ),
        _section('Appearance', [
          _colorSchemeTile(context),
        ]),
        _section('Playback', [
          _playbackTile(),
        ]),
        _scrobbleSection(context),
        _section('Library & Storage', [
          _tile(Icons.folder_special, 'Music folders', 'Choose which folders to scan', onTap: () => Get.to(() => const FolderPickerScreen())),
          _tile(Icons.search, 'Scan device', 'Find all music on your device', onTap: () => LibraryController.inst.scanLibrary()),
          Obx(() {
            final lib = LibraryController.inst;
            return _tile(Icons.library_music, 'Library', '${lib.tracks.length} tracks · ${lib.albums.length} albums · ${lib.artists.length} artists');
          }),
          _tile(Icons.delete_outline, 'Clear library', 'Remove all tracks (re-scan to restore)',
            color: kBrandCoral,
            onTap: () => Get.dialog(AlertDialog(
              backgroundColor: kBg1,
              title: const Text('Clear library?', style: TextStyle(color: kFg1)),
              content: const Text('All tracks will be removed. Your music files are not deleted.', style: TextStyle(color: kFg2)),
              actions: [
                TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: kFg2))),
                TextButton(onPressed: () { LibraryController.inst.tracks.clear(); Get.back(); }, child: const Text('Clear', style: TextStyle(color: kBrandCoral))),
              ],
            )),
          ),
        ]),
        _section('About', [
          _tile(Icons.music_note, 'Version', 'AURADEC 2.0.0 · Flutter · ExoPlayer'),
          _tile(Icons.info_outline, 'Audio engine', 'ExoPlayer · just_audio · MediaSession'),
        ]),
        _section('Credits', [
          _tile(Icons.headphones, 'AURADEC', 'Sound for every culture'),
          _tile(Icons.code, 'Built with', 'Flutter · Dart · ExoPlayer · MediaSession'),
        ]),
      ])),
    );
  }

  Widget _colorSchemeTile(BuildContext context) {
    return Obx(() {
      final tc = ThemeController.inst;
      final accent = tc.accent.value;
      final sec    = tc.secondary.value;
      return InkWell(
        onTap: () => _showSchemeSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            const Icon(Icons.palette_outlined, color: kBrandOrange, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Color scheme', style: TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(kSchemes.firstWhereOrNull((s) => s.id == tc.schemeId.value)?.name ?? 'Custom',
                  style: const TextStyle(color: kFg2, fontSize: 11)),
            ])),
            Container(
              width: 32, height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: sec != null
                    ? LinearGradient(colors: [accent, sec])
                    : null,
                color: sec == null ? accent : null,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: kFg3, size: 18),
          ]),
        ),
      );
    });
  }

  void _showSchemeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Obx(() {
        final tc = ThemeController.inst;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Color scheme', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 14, children: kSchemes.map((s) {
              final active = tc.schemeId.value == s.id;
              return GestureDetector(
                onTap: () async {
                  await tc.setScheme(s.id);
                  // ThemeController is GetBuilder-driven; update manually
                  Get.find<ThemeController>().update();
                  Get.back();
                },
                child: Column(children: [
                  Stack(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: s.secondary != null
                            ? LinearGradient(colors: [s.accent, s.secondary!])
                            : null,
                        color: s.secondary == null ? s.accent : null,
                        border: Border.all(
                          color: active ? Colors.white : Colors.transparent, width: 2),
                      ),
                    ),
                    if (active)
                      const Positioned(right: 4, bottom: 4,
                        child: Icon(Icons.check_circle, color: Colors.white, size: 14)),
                  ]),
                  const SizedBox(height: 4),
                  Text(s.name, style: TextStyle(
                    color: active ? kFg1 : kFg2,
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  )),
                ]),
              );
            }).toList()),
          ]),
        );
      }),
    );
  }

  Widget _playbackTile() {
    return StreamBuilder<double>(
      stream: AuradecAudioHandler.inst.volume,
      builder: (_, snap) {
        final vol = snap.data ?? 0.85;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.volume_up_outlined, color: kBrandOrange, size: 20),
              const SizedBox(width: 14),
              const Text('Volume', style: TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${(vol * 100).round()}%', style: const TextStyle(color: kBrandOrange, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            Slider(
              value: vol, min: 0, max: 1,
              activeColor: kBrandOrange, inactiveColor: kBorder,
              onChanged: (v) => AuradecAudioHandler.inst.setVolume(v),
            ),
          ]),
        );
      },
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title.toUpperCase(), style: const TextStyle(color: kBrandGold, fontSize: 8, letterSpacing: 2.5, fontFamily: 'Barlow')),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: kBg1, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
        child: Column(children: children),
      ),
    ],
  );

  Widget _tile(IconData icon, String title, String subtitle, {VoidCallback? onTap, Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, color: color ?? kBrandOrange, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: color ?? kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(subtitle, style: const TextStyle(color: kFg2, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          if (onTap != null) Icon(Icons.chevron_right, color: kFg3, size: 18),
        ]),
      ),
    );
  }

  // ── Scrobbling section ─────────────────────────────────────────────

  Widget _scrobbleSection(BuildContext context) {
    final svc = ScrobbleService.inst;
    return _section('Scrobbling', [
      _scrobbleTile(
        context: context,
        icon: Icons.album_outlined,
        title: 'Last.fm',
        connected: svc.lfmConnected,
        onTap: () => _showLfmSheet(context),
      ),
      _scrobbleTile(
        context: context,
        icon: Icons.hearing_outlined,
        title: 'ListenBrainz',
        connected: svc.lbzConnected,
        onTap: () => _showLbzSheet(context),
      ),
      Obx(() => _tile(
        Icons.bar_chart_outlined,
        'Scrobbles',
        '${svc.scrobbleCount.value} tracks submitted this session',
      )),
    ]);
  }

  Widget _scrobbleTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool connected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, color: kBrandOrange, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(connected ? 'Connected' : 'Not connected',
                style: TextStyle(color: connected ? kBrandGreen : kFg2, fontSize: 11)),
          ])),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? kBrandGreen : kFg3,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: kFg3, size: 18),
        ]),
      ),
    );
  }

  void _showLfmSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => LfmSheet(svc: ScrobbleService.inst),
    );
  }

  void _showLbzSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => LbzSheet(svc: ScrobbleService.inst),
    );
  }
}
