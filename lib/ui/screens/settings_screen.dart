import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants.dart';
import 'settings_audio_screen.dart';
import 'settings_playback_screen.dart';
import 'settings_sync_screen.dart';
import 'settings_scrobble_screen.dart';

// ── Settings main screen ─────────────────────────────────────────────────────
// Shows 4 sections: Audio · Playback · Devices & Sync · Scrobbling
// Each opens a full dedicated screen with all reference panel content.

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
        // ── Title ─────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Settings', style: TextStyle(
              color: kFg1, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Syne')),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text('Maximum configurability, organised.',
              style: TextStyle(color: kFg2, fontSize: 12, fontFamily: 'Barlow', fontWeight: FontWeight.w300)),
        ),

        // ── SOUND ─────────────────────────────────────────────────
        _groupLabel('Sound', kBrandGold),
        _groupCard([
          _navTile(Icons.graphic_eq, 'Audio', 'Output · codec · sample rate', kBrandGold,
              onTap: () => Get.to(() => const SettingsAudioScreen())),
          _navTile(Icons.tune, 'Playback', 'Crossfade · gapless · normalise', kBrandGold,
              onTap: () => Get.to(() => const SettingsPlaybackScreen())),
        ]),

        // ── CONNECTIVITY ──────────────────────────────────────────
        _groupLabel('Connectivity', const Color(0xFF60A5FA)),
        _groupCard([
          _navTile(Icons.wifi, 'Devices & Sync', 'Phone ⇄ PC · server role', const Color(0xFF60A5FA),
              onTap: () => Get.to(() => const SettingsSyncScreen())),
          _navTile(Icons.album_outlined, 'Scrobbling', 'Last.fm · ListenBrainz · webhook', kBrandCoral,
              onTap: () => Get.to(() => const SettingsScrobbleScreen())),
        ]),
      ])),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Widget _groupLabel(String label, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(label.toUpperCase(), style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5, fontFamily: 'Barlow')),
  );

  static Widget _groupCard(List<Widget> children) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: kBg1, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder)),
    child: Column(children: children),
  );

  static Widget _navTile(IconData icon, String title, String subtitle, Color iconColor,
      {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(22), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                color: kFg1, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(subtitle, style: const TextStyle(color: kFg2, fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_right, color: kFg3, size: 18),
        ]),
      ),
    );
  }
}
