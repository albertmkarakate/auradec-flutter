import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants.dart';
import '../services/audio_handler.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/now_playing_screen.dart';
import 'widgets/mini_player.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0=Library 1=Search 2=Radio 3=Settings (NowPlaying is push-route, not a tab)
  int _tab = 0;

  static const _screens = [
    LibraryScreen(),
    SearchScreen(),
    RadioScreen(),
    SettingsScreen(),
  ];

  void _handleNav(int idx) {
    if (idx == 3) {
      // "Playing" tab — push NowPlaying if track active, else show hint
      if (AuradecAudioHandler.inst.currentTrackValue != null) {
        Get.to(() => const NowPlayingScreen(), fullscreenDialog: true);
      } else {
        Get.snackbar('', 'Nothing is playing',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: kBg2,
          colorText: kFg1,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 80),
          duration: const Duration(seconds: 2),
          borderRadius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          messageText: const Text('Nothing is playing', style: TextStyle(color: kFg1, fontSize: 13)),
          titleText: const SizedBox.shrink(),
        );
      }
      return;
    }
    // Map nav index to screen index (skip index 3 which is NowPlaying action)
    final screenIdx = idx < 3 ? idx : idx - 1; // 0,1,2 → 0,1,2; 4 → 3
    setState(() => _tab = screenIdx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: Column(children: [
        Expanded(child: IndexedStack(index: _tab, children: _screens)),
        StreamBuilder(
          stream: AuradecAudioHandler.inst.currentTrack,
          builder: (_, snap) => snap.data != null
              ? GestureDetector(
                  onTap: () => Get.to(() => const NowPlayingScreen(), fullscreenDialog: true),
                  child: const MiniPlayer(),
                )
              : const SizedBox.shrink(),
        ),
        _buildNav(),
      ]),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: BoxDecoration(
        color: kBg1,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _navItem(0, Icons.library_music_outlined, Icons.library_music,   'Library'),
            _navItem(1, Icons.search,                  Icons.search,          'Search'),
            _navItem(2, Icons.radio_outlined,          Icons.radio,           'Radio'),
            _navItemPlaying(),
            _navItem(4, Icons.settings_outlined,       Icons.settings,        'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int navIdx, IconData icon, IconData iconActive, String label) {
    // Map nav index to screen tab index
    final screenIdx = navIdx < 3 ? navIdx : navIdx - 1;
    final active = _tab == screenIdx && navIdx != 3;
    return Expanded(
      child: InkWell(
        onTap: () => _handleNav(navIdx),
        child: Builder(builder: (ctx) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(active ? iconActive : icon,
                  color: active ? accent : kFg3, size: 22),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(
                color: active ? accent : kFg3,
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.5,
              )),
            ]),
          );
        }),
      ),
    );
  }

  Widget _navItemPlaying() {
    return Expanded(
      child: InkWell(
        onTap: () => _handleNav(3),
        child: StreamBuilder(
          stream: AuradecAudioHandler.inst.currentTrack,
          builder: (ctx, snap) {
            final hasTrack = snap.data != null;
            final accent = Theme.of(ctx).colorScheme.primary;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Stack(alignment: Alignment.topCenter, children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(alignment: Alignment.center, children: [
                    Icon(Icons.album_outlined, color: hasTrack ? accent : kFg3, size: 22),
                    if (hasTrack)
                      // Pulse indicator dot
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                            color: accent, shape: BoxShape.circle,
                            border: Border.all(color: kBg1, width: 1.5),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text('Playing', style: TextStyle(
                    color: hasTrack ? accent : kFg3,
                    fontSize: 9,
                    fontWeight: hasTrack ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.5,
                  )),
                ]),
              ]),
            );
          },
        ),
      ),
    );
  }
}
