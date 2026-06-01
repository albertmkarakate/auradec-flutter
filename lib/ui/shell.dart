import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/constants.dart';
import '../services/audio_handler.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'screens/radio_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/now_playing_screen.dart';
import 'widgets/mini_player.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static final _screens = [
    const LibraryScreen(),
    const SearchScreen(),
    const RadioScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg0,
      body: Column(children: [
        Expanded(
          child: IndexedStack(index: _tab, children: _screens),
        ),
        // Mini player above nav bar
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
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.library_music_outlined, Icons.library_music, 'Library'),
            _navItem(1, Icons.search, Icons.search, 'Search'),
            _navItem(2, Icons.radio_outlined, Icons.radio, 'Radio'),
            _navItem(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Stats'),
            _navItem(4, Icons.settings_outlined, Icons.settings, 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, IconData iconActive, String label) {
    final active = _tab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = idx),
        child: Builder(builder: (ctx) {
          final accent = Theme.of(ctx).colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(active ? iconActive : icon, color: active ? accent : kFg3, size: 22),
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
}
