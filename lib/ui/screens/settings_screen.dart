import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text('Settings', style: TextStyle(color: kFg1, fontSize: 22, fontWeight: FontWeight.w800)),
        ),

        // ── PERSONALISE ───────────────────────────────────────────
        _groupLabel('Personalise', kBrandOrange),
        _groupCard([
          _colorSchemeTile(context),
          _navTile(Icons.density_medium, 'Density',
              'Compact · Comfy · Loose list spacing', kBrandOrange,
              onTap: () => _showDensitySheet()),
        ]),

        // ── SOUND ─────────────────────────────────────────────────
        _groupLabel('Sound', kBrandGold),
        _groupCard([
          _navTile(Icons.graphic_eq, 'Audio',
              'Output · codec · sample rate', kBrandGold,
              onTap: () => _showAudioSheet(context)),
          _navTile(Icons.tune, 'Playback',
              'Crossfade · gapless · normalise', kBrandGold,
              onTap: () => _showPlaybackSheet()),
          _navTile(Icons.equalizer, 'Equaliser',
              '10-band EQ · presets', kBrandGold,
              onTap: () => _showEQSheet()),
        ]),

        // ── LIBRARY ───────────────────────────────────────────────
        _groupLabel('Library', kBrandGreen),
        _groupCard([
          _navTile(Icons.folder_special_outlined, 'Music folders',
              'Choose which folders to scan', kBrandGreen,
              onTap: () => Get.to(() => const FolderPickerScreen())),
          Obx(() {
            final lib = LibraryController.inst;
            return _navTile(Icons.search, 'Scan device',
                lib.isScanning.value ? 'Scanning…' : '${lib.tracks.length} tracks in library',
                kBrandGreen,
                onTap: lib.isScanning.value ? null : () => lib.scanLibrary(),
                trailing: lib.isScanning.value
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: kBrandGreen, strokeWidth: 2))
                    : null);
          }),
          _navTile(Icons.delete_outline, 'Clear library',
              'Remove all tracks from library', kBrandCoral,
              onTap: () => _confirmClear()),
        ]),

        // ── METADATA & TAGS ───────────────────────────────────────
        _groupLabel('Metadata & Tags', kBrandGold),
        _groupCard([
          _navTile(Icons.edit_note, 'Artist separators',
              'feat. · ft. · & · , — split multi-artist tags', kBrandGold,
              onTap: () => _showArtistSepsSheet(context)),
          _navTile(Icons.image_search, 'Artwork cache',
              'Clear embedded cover art cache', kBrandGold,
              onTap: () {}),
          _navTile(Icons.library_books_outlined, 'MusicBrainz',
              'Auto-tag tracks on import', kBrandGold,
              onTap: () {}),
        ]),

        // ── INTELLIGENCE ──────────────────────────────────────────
        _groupLabel('Intelligence', const Color(0xFFA78BFA)),
        _groupCard([
          _navTile(Icons.auto_awesome, 'AI engine',
              'Artist bios · similar artists · auto-fix', const Color(0xFFA78BFA),
              onTap: () => _showIntelligenceSheet(context)),
          _navTile(Icons.record_voice_over_outlined, 'Biography source',
              'Wikipedia · Last.fm · AI auto-research', const Color(0xFFA78BFA),
              onTap: () {}),
        ]),

        // ── CONNECTIVITY ──────────────────────────────────────────
        _groupLabel('Connectivity', const Color(0xFF60A5FA)),
        _groupCard([
          _navTile(Icons.wifi, 'Devices & Sync',
              'Phone ⇄ PC · server role', const Color(0xFF60A5FA),
              onTap: () {}),
          _navTile(Icons.radio_outlined, 'Scrobbling',
              'Last.fm · ListenBrainz · webhook', const Color(0xFF60A5FA),
              onTap: () => _showScrobbleSheet(context)),
        ]),

        // ── ANDROID ───────────────────────────────────────────────
        _groupLabel('Android', const Color(0xFF34D399)),
        _groupCard([
          _navTile(Icons.notifications_outlined, 'Notifications',
              'Channels · lock screen · widget', const Color(0xFF34D399),
              onTap: () => _openAndroidNotificationSettings(),
              badge: 'ANDROID'),
          _navTile(Icons.battery_charging_full_outlined, 'Battery & Service',
              'Background · wake lock · foreground', const Color(0xFF34D399),
              onTap: () => _openAndroidBatterySettings(),
              badge: 'ANDROID'),
          _navTile(Icons.bluetooth_outlined, 'Bluetooth & Audio',
              'LDAC · aptX · A2DP profile', const Color(0xFF34D399),
              onTap: () => _openBluetoothSettings(),
              badge: 'ANDROID'),
          _navTile(Icons.directions_car_outlined, 'Android Auto',
              'Car display · playback mode', const Color(0xFF34D399),
              onTap: () {},
              badge: 'ANDROID'),
          _navTile(Icons.watch_outlined, 'Wear OS',
              'Companion sync · watch controls', const Color(0xFF34D399),
              onTap: () {},
              badge: 'ANDROID'),
          _navTile(Icons.grid_view_outlined, 'Widget & Quick Tile',
              'Home screen & Quick Settings', const Color(0xFF34D399),
              onTap: () {},
              badge: 'ANDROID'),
          _navTile(Icons.folder_outlined, 'Storage & SAF',
              'Scoped storage · cache · paths', const Color(0xFF34D399),
              onTap: () {},
              badge: 'ANDROID'),
        ]),

        // ── ACCESSIBILITY ─────────────────────────────────────────
        _groupLabel('Accessibility', kFg3),
        _groupCard([
          _navTile(Icons.accessibility_new_outlined, 'Accessibility',
              'Text size · TalkBack · motion', kFg2,
              onTap: () {}),
        ]),

        // ── ABOUT ─────────────────────────────────────────────────
        _groupLabel('About', kFg3),
        _groupCard([
          _navTile(Icons.headphones, 'AURADEC 2.0.0',
              'Sound for every culture', kFg2),
          _navTile(Icons.info_outline, 'Audio engine',
              'ExoPlayer · just_audio · MediaSession', kFg2),
          _navTile(Icons.code, 'Built with',
              'Flutter · Dart · ExoPlayer', kFg2),
          Obx(() {
            final lib = LibraryController.inst;
            final totalMs = lib.tracks.fold(0, (s, t) => s + t.durationMs);
            final totalH  = totalMs ~/ 3600000;
            final totalM  = (totalMs % 3600000) ~/ 60000;
            return _navTile(Icons.storage_outlined, 'Catalog',
                '${lib.tracks.length} tracks · ${totalH}h ${totalM}m total', kFg2);
          }),
        ]),
      ])),
    );
  }

  // ── Group layout helpers ─────────────────────────────────────────

  Widget _groupLabel(String label, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(label.toUpperCase(), style: TextStyle(
      color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
  );

  Widget _groupCard(List<Widget> children) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: kBg1, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder)),
    child: Column(children: children),
  );

  Widget _navTile(IconData icon, String title, String subtitle, Color iconColor,
      {VoidCallback? onTap, Widget? trailing, String? badge}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(22),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF34D399).withAlpha(60)),
                  ),
                  child: Text(badge, style: const TextStyle(
                    color: Color(0xFF34D399), fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
              ],
            ]),
            Text(subtitle, style: const TextStyle(color: kFg2, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          trailing ?? (onTap != null
              ? const Icon(Icons.chevron_right, color: kFg3, size: 18)
              : const SizedBox.shrink()),
        ]),
      ),
    );
  }

  void _showDensitySheet() {
    const opts = ['Compact', 'Comfy', 'Loose'];
    const descs = ['More tracks visible', 'Balanced (default)', 'Larger touch targets'];
    showModalBottomSheet(
      context: Get.context!, backgroundColor: kBg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Obx(() {
        final tc = ThemeController.inst;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Density', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...List.generate(3, (i) => ListTile(
              title: Text(opts[i], style: TextStyle(
                  color: tc.density.value == i ? kBrandOrange : kFg1,
                  fontWeight: tc.density.value == i ? FontWeight.w700 : FontWeight.normal)),
              subtitle: Text(descs[i], style: const TextStyle(color: kFg2, fontSize: 11)),
              trailing: tc.density.value == i
                  ? const Icon(Icons.check, color: kBrandOrange, size: 18) : null,
              onTap: () { tc.setDensity(i); Get.back(); },
            )),
          ]),
        );
      })),
    );
  }

  void _showAudioSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Audio', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _sheetRow('Output device', 'System default', Icons.speaker_outlined),
          _sheetRow('Audio codec', 'AAC / MP3 / FLAC', Icons.audiotrack_outlined),
          _sheetRow('Sample rate', '44.1 kHz', Icons.waves_outlined),
          _sheetRow('Bit depth', '16-bit', Icons.memory_outlined),
          _sheetRow('Resampler', 'SoX HQ', Icons.graphic_eq),
        ]),
      )),
    );
  }

  Widget _sheetRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: kFg3, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: kFg1, fontSize: 13))),
        Text(value, style: const TextStyle(color: kFg2, fontSize: 12)),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right, color: kFg3, size: 16),
      ]),
    );
  }

  void _showPlaybackSheet() {
    showModalBottomSheet(
      context: Get.context!, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Playback', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700))),
            _playbackTile(),
            _playbackToggles(),
            const SizedBox(height: 24),
          ]),
        )),
      ),
    );
  }

  void _showEQSheet() {
    showModalBottomSheet(
      context: Get.context!, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _EQSheetStandalone(),
    );
  }

  void _showScrobbleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        top: false,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Scrobbling', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700))),
          _scrobbleSection(context),
          const SizedBox(height: 24),
        ])),
      ),
    );
  }

  void _confirmClear() {
    Get.dialog(AlertDialog(
      backgroundColor: kBg1,
      title: const Text('Clear library?', style: TextStyle(color: kFg1)),
      content: const Text('All tracks will be removed. Files are not deleted.',
          style: TextStyle(color: kFg2)),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel', style: TextStyle(color: kFg2))),
        TextButton(onPressed: () { LibraryController.inst.tracks.clear(); Get.back(); },
            child: const Text('Clear', style: TextStyle(color: kBrandCoral))),
      ],
    ));
  }

  void _openAndroidNotificationSettings() {
    const channel = MethodChannel('app.auradec/system');
    channel.invokeMethod('openNotificationSettings').catchError((_) {});
  }

  void _openAndroidBatterySettings() {
    const channel = MethodChannel('app.auradec/system');
    channel.invokeMethod('openBatterySettings').catchError((_) {});
  }

  void _openBluetoothSettings() {
    const channel = MethodChannel('app.auradec/system');
    channel.invokeMethod('openBluetoothSettings').catchError((_) {});
  }

  void _showArtistSepsSheet(BuildContext context) {
    const seps = [
      ['feat.', 'Featured artist'],
      ['ft.',   'Featured (short)'],
      ['&',     'Ampersand'],
      [',',     'Comma'],
      [';',     'Semicolon'],
      ['x',     'Collab (x)'],
      ['vs',    'Versus'],
      ['with',  'With'],
    ];
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('METADATA & TAGS', style: TextStyle(
              color: kBrandGold, fontSize: 9, letterSpacing: 2.5, fontFamily: 'Barlow')),
          const SizedBox(height: 4),
          const Text('Artist Separators', style: TextStyle(
              color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
          const SizedBox(height: 6),
          const Text(
            'Tokens that split a multi-artist tag into individual, linkable artists. '
            'e.g. "Burna Boy feat. Wizkid" → "Burna Boy" + "Wizkid"',
            style: TextStyle(color: kFg2, fontSize: 12, height: 1.5)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: seps.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: kBrandOrange.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBrandOrange.withAlpha(50))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(s[0], style: const TextStyle(
                  color: kBrandOrange, fontSize: 12, fontFamily: 'Barlow', fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(s[1], style: const TextStyle(color: kFg2, fontSize: 11)),
            ]),
          )).toList()),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kBg2, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Live preview', style: TextStyle(
                  color: kFg3, fontSize: 8, letterSpacing: 1.5, fontFamily: 'Barlow')),
              const SizedBox(height: 8),
              const Text('"Davido, Musa Keys feat. Toni Braxton"',
                  style: TextStyle(color: kFg2, fontSize: 11, fontFamily: 'Barlow')),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final name in ['Davido', 'Musa Keys', 'Toni Braxton'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kBrandOrange.withAlpha(20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kBrandOrange.withAlpha(40))),
                    child: Text(name, style: const TextStyle(
                        color: kBrandOrange, fontSize: 11, fontWeight: FontWeight.w500))),
              ]),
            ]),
          ),
        ]),
      )),
    );
  }

  void _showIntelligenceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: kBg1, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(top: false, child: SingleChildScrollView(child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('INTELLIGENCE', style: TextStyle(
                color: Color(0xFFA78BFA), fontSize: 9, letterSpacing: 2.5, fontFamily: 'Barlow'))),
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text('AI Engine', style: TextStyle(
                color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne'))),
          _settingRow(Icons.auto_awesome, 'Artist biographies',
              'Fetch from Wikipedia on first view', trailing: Switch(
                value: true, onChanged: (_) {},
                activeColor: const Color(0xFFA78BFA), inactiveTrackColor: kBorder)),
          _settingRow(Icons.people_outline, 'Similar artists',
              'Show in Now Playing screen', trailing: Switch(
                value: true, onChanged: (_) {},
                activeColor: const Color(0xFFA78BFA), inactiveTrackColor: kBorder)),
          _settingRow(Icons.translate, 'Lyric translation',
              'Auto-translate non-English lyrics', trailing: Switch(
                value: false, onChanged: (_) {},
                activeColor: const Color(0xFFA78BFA), inactiveTrackColor: kBorder)),
          _settingRow(Icons.refresh, 'Bio refresh cadence',
              'Re-fetch artist biographies', trailing: DropdownButton<String>(
                value: 'Weekly',
                dropdownColor: kBg2,
                style: const TextStyle(color: kFg1, fontSize: 12),
                underline: const SizedBox.shrink(),
                items: ['Off', 'Daily', 'Weekly', 'Monthly']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (_) {},
              )),
        ]),
      ))),
    );
  }

  Widget _settingRow(IconData icon, String title, String subtitle, {required Widget trailing}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(icon, color: kFg2, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(subtitle, style: const TextStyle(color: kFg2, fontSize: 11)),
        ])),
        trailing,
      ]),
    );

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
      builder: (_) => SafeArea(child: Obx(() {
        final tc = ThemeController.inst;
        return SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
        ));
      })),
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

  Widget _playbackToggles() {
    return Obx(() {
      final h = AuradecAudioHandler.inst;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          _switchRow(
            icon: Icons.skip_next_outlined,
            title: 'Gapless playback',
            subtitle: 'No silence between tracks',
            value: h.gaplessEnabled.value,
            onChanged: (v) => h.setGapless(v),
          ),
          _switchRow(
            icon: Icons.speed,
            title: 'Skip silence',
            subtitle: 'Jump over quiet passages',
            value: h.skipSilenceEnabled.value,
            onChanged: (v) => h.setSkipSilence(v),
          ),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.swap_horiz, color: kBrandOrange, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Crossfade', style: TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(h.crossfadeSecs.value == 0
                  ? 'Off' : '${h.crossfadeSecs.value}s fade between tracks',
                  style: const TextStyle(color: kFg2, fontSize: 11)),
            ])),
            Text('${h.crossfadeSecs.value}s',
                style: const TextStyle(color: kBrandOrange, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          Slider(
            value: h.crossfadeSecs.value.toDouble(),
            min: 0, max: 10, divisions: 10,
            activeColor: kBrandOrange, inactiveColor: kBorder,
            onChanged: (v) => h.setCrossfade(v.round()),
          ),
        ]),
      );
    });
  }

  Widget _switchRow({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: kBrandOrange, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(subtitle, style: const TextStyle(color: kFg2, fontSize: 11)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: kBrandOrange,
          inactiveTrackColor: kBorder,
        ),
      ]),
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

// Standalone EQ sheet reusing the logic from NowPlayingScreen
class _EQSheetStandalone extends StatefulWidget {
  const _EQSheetStandalone();
  @override
  State<_EQSheetStandalone> createState() => _EQSheetStandaloneState();
}

class _EQSheetStandaloneState extends State<_EQSheetStandalone> {
  final _bands  = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  final _freqs  = ['32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];
  String _preset = 'Flat';
  final _presets = {
    'Flat':  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass+': [6.0, 5.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Vocal': [-2.0,-1.0, 0.0, 2.0, 4.0, 4.0, 3.0, 1.0, 0.0,-1.0],
    'Rock':  [4.0, 3.0, 2.0, 0.0,-1.0,-1.0, 1.0, 3.0, 4.0, 4.0],
  };

  @override
  Widget build(BuildContext context) {
    final h = AuradecAudioHandler.inst;
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Equaliser', style: TextStyle(color: kFg1, fontSize: 16, fontWeight: FontWeight.w700)),
          const Icon(Icons.equalizer, color: kBrandOrange),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: _presets.keys.map((p) => FilterChip(
          label: Text(p), selected: _preset == p,
          onSelected: (_) {
            setState(() { _preset = p; for (int i = 0; i < 10; i++) _bands[i] = _presets[p]![i]; });
            h.setEQEnabled(true);
            for (int i = 0; i < 10; i++) h.setEQBand(i, _presets[p]![i]);
          },
          backgroundColor: kBg2, selectedColor: kBrandOrange.withAlpha(40),
          labelStyle: TextStyle(color: _preset == p ? kBrandOrange : kFg2, fontSize: 11),
          side: BorderSide(color: _preset == p ? kBrandOrange : kBorder),
        )).toList()),
        const SizedBox(height: 16),
        SizedBox(height: 160, child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(10, (i) => Expanded(child: Column(
            mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${_bands[i] > 0 ? '+' : ''}${_bands[i].toInt()}',
                  style: TextStyle(color: _bands[i] == 0 ? kFg3 : kBrandOrange, fontSize: 8)),
              const SizedBox(height: 4),
              Expanded(child: RotatedBox(quarterTurns: 3, child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                child: Slider(value: _bands[i], min: -12, max: 12,
                  activeColor: kBrandOrange, inactiveColor: kBorder,
                  onChanged: (v) {
                    setState(() { _bands[i] = v.roundToDouble(); _preset = 'Custom'; });
                    h.setEQEnabled(true);
                    h.setEQBand(i, v);
                  },
                ),
              ))),
              Text(_freqs[i], style: const TextStyle(color: kFg3, fontSize: 7)),
          ]))),
        )),
      ]),
    ));
  }
}
